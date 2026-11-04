#include <fcitx/action.h>
#include <fcitx/addonfactory.h>
#include <fcitx/addonmanager.h>
#include <fcitx/inputmethodengine.h>
#include <fcitx/inputcontext.h>
#include <fcitx/instance.h>
#include <fcitx/inputpanel.h>
#include <fcitx/statusarea.h>
#include <fcitx/text.h>
#include <fcitx/candidatelist.h>
#include <fcitx/userinterfacemanager.h>
#include <fcitx-config/configuration.h>
#include <fcitx-config/iniparser.h>
#include <fcitx-config/option.h>
#include <fcitx-utils/dbus/bus.h>
#include <fcitx-utils/log.h>
#include <fcitx-utils/misc.h>
#include <cloudpinyin_public.h>
#include <systemd/sd-bus.h>
#include <algorithm>
#include <chrono>
#include <cstdlib>
#include <fstream>
#include <map>
#include <memory>
#include <functional>
#include <string_view>
#include <unistd.h>

using namespace fcitx;
namespace {
constexpr auto imInterface = "org.fcitx.Fcitx.InputMethod";
constexpr auto icInterface = "org.fcitx.Fcitx.InputContext";
struct Context {
    TrackableObjectReference<InputContext> reference;
    std::string path;
};
constexpr auto cloudSign = "\xe2\x98\x81";
class SogouCandidate final : public CandidateWord {
public:
    SogouCandidate(const std::string &word, std::function<void(InputContext *)> select,
                   const std::string &comment = {}, bool placeHolder = false)
        : CandidateWord(Text(word)), select_(std::move(select)) {
        if (!comment.empty()) setComment(Text(comment));
        setPlaceHolder(placeHolder);
    }
    void select(InputContext *ic) const override { select_(ic); }
private:
    std::function<void(InputContext *)> select_;
};
// Fcitx 5's settings show SogouSettings as a button that runs the command, the
// same way Mozc offers its configuration tool.
class BridgeConfig final : public Configuration {
public:
    explicit BridgeConfig(std::string command = {})
        : settings(this, "SogouSettings", "搜狗输入法设置", std::move(command)) {}
    const char *typeName() const override { return "SogouBridgeConfig"; }
    ExternalOption settings;
    // This Linux build of Sogou never sends its own cloud requests. Fcitx 5's
    // Cloud Pinyin module supplies one candidate instead; its backend (Baidu,
    // Google) is chosen in that module's settings.
    Option<bool> cloud{this, "CloudPinyin", "显示云拼音候选", true};
};
constexpr auto configFile = "conf/sogoubridge.conf";

class SogouBridge final : public InputMethodEngineV2 {
public:
    explicit SogouBridge(AddonManager *manager) : manager_(manager) {
        reconnectTimer_ = manager_->eventLoop()->addTimeEvent(
            CLOCK_MONOTONIC, now(CLOCK_MONOTONIC) + 250000, 0,
            [this](EventSourceTime *source, uint64_t) {
                // Recover while idle, before the first key after a backend restart.
                if (auto *ic = active_.get(); ic && ic->hasFocus()) ensure(ic);
                source->setNextInterval(250000);
                source->setOneShot();
                return true;
            });
        // Fcitx 5's AltTriggerKeys (Shift_L by default) turns a Shift tap into
        // an input method switch and drops the pinyin being typed. Sogou does
        // its own Chinese/English toggle on Shift, so it sees Shift first.
        shiftWatcher_ = manager_->instance()->watchEvent(
            EventType::InputContextKeyEvent, EventWatcherPhase::PreInputMethod,
            [this](Event &event) {
                auto &keyEvent = static_cast<KeyEvent &>(event);
                auto *ic = keyEvent.inputContext();
                const auto key = keyEvent.rawKey();
                if ((key.sym() != FcitxKey_Shift_L && key.sym() != FcitxKey_Shift_R) ||
                    manager_->instance()->inputMethodEngine(ic) != this)
                    return;
                active_ = ic->watch();
                if (process(ic, key, keyEvent.isRelease(), keyEvent.time()))
                    keyEvent.filterAndAccept();
                else
                    keyEvent.filter();
            });
        // Sogou's own settings window, from the tray menu.
        settingsAction_.setShortText("搜狗设置");
        settingsAction_.setIcon("configure");
        settingsAction_.connect<SimpleAction::Activated>([this](InputContext *) {
            if (auto path = launcher(); !path.empty()) startProcess({path, "--settings"});
        });
        manager_->instance()->userInterfaceManager().registerAction("sogou-settings", &settingsAction_);
        readAsIni(config_, configFile);
    }
    ~SogouBridge() override {
        shiftWatcher_.reset();
        reconnectTimer_.reset();
        modeMatch_.reset();
        candidatesMatch_.reset();
        ownerMatch_.reset();
        match_.reset();
        if (bus_) bus_->detachEventLoop();
    }

    void activate(const InputMethodEntry &, InputContextEvent &event) override {
        active_ = event.inputContext()->watch();
        forget();
        event.inputContext()->statusArea().addAction(StatusGroup::InputMethod, &settingsAction_);
        auto *ctx = ensure(event.inputContext());
        if (!ctx) return;
        if (!focus(*ctx)) {
            contexts_.erase(event.inputContext());
            if (auto *fresh = ensure(event.inputContext())) focus(*fresh);
        }
        // Sogou keeps its mode in the shared backend, even after FocusOut.
        // Enter Chinese when this input method is activated again instead of
        // inheriting English from the previous window or activation. Use
        // Sogou's own toggle so the engine and its status stay in sync.
        pumpBus();
        if (english_) {
            process(event.inputContext(), Key(FcitxKey_Shift_L), false, 0);
            process(event.inputContext(), Key(FcitxKey_Shift_L), true, 0);
        }
    }
    void deactivate(const InputMethodEntry &, InputContextEvent &event) override {
        auto *ic = event.inputContext();
        if (active_.get() == ic) active_.unwatch();
        clearBackend(ic, true);
        ic->inputPanel().reset();
        ic->updatePreedit();
        ic->updateUserInterface(UserInterfaceComponent::InputPanel);
    }
    void reset(const InputMethodEntry &, InputContextEvent &event) override {
        auto *ic = event.inputContext();
        clearBackend(ic, false);
        ic->inputPanel().reset();
        ic->updatePreedit();
        ic->updateUserInterface(UserInterfaceComponent::InputPanel);
    }
    void keyEvent(const InputMethodEntry &, KeyEvent &event) override {
        active_ = event.inputContext()->watch();
        if (!event.isRelease() && cloudKey(event)) {
            event.filterAndAccept();
            return;
        }
        // Ask synchronously so that a key Sogou does not want goes back through
        // the frontend untouched. Forwarding it afterwards lost modifiers on
        // Wayland and broke shortcuts such as Ctrl+A.
        if (process(event.inputContext(), sogouKey(event), event.isRelease(), event.time()))
            event.filterAndAccept();
    }
    std::string subModeIconImpl(const InputMethodEntry &, InputContext &) override {
        return english_ ? "input-keyboard" : "";
    }
    std::string subModeLabelImpl(const InputMethodEntry &, InputContext &) override {
        return english_ ? "英" : "";
    }
    std::string subMode(const InputMethodEntry &, InputContext &) override {
        return english_ ? "英文" : "";
    }
    const Configuration *getConfigForInputMethod(const InputMethodEntry &) const override {
        auto path = launcher();
        settingsConfig_ = std::make_unique<BridgeConfig>(path.empty() ? "" : path + " --settings");
        settingsConfig_->cloud.setValue(*config_.cloud);
        return settingsConfig_.get();
    }
    void setConfigForInputMethod(const InputMethodEntry &, const RawConfig &config) override {
        config_.load(config, true);
        safeSaveAsIni(config_, configFile);
    }
private:
    FCITX_ADDON_DEPENDENCY_LOADER(cloudpinyin, (*manager_))
    // The cloud request for the pinyin Sogou is composing, and its result.
    struct Cloud {
        std::string pinyin, prefix, word;
        bool filled = false;
        // A late empty or repeated result keeps its slot so labels do not shift.
        bool keepSlot = false;
        std::chrono::steady_clock::time_point started;
    };
    struct PendingKey {
        InputContext *ic;
        Key key;
        bool release;
        bool hadPreedit;
        bool sawCandidates = false;
        bool sawCommit = false;
        bool sawForward = false;
        bool sawMode = false;
        bool deferredClear = false;
    };
    void forget() {
        preedit_.clear();
        words_.clear();
        cloud_ = {};
        ++cloudGeneration_;
        cloudFocused_ = false;
        cloudIndex_ = -1;
    }
    sd_bus *rawBus() const {
        if (!bus_ || std::string_view(dbus::Bus::impl()) != "sdbus") return nullptr;
        auto *raw = static_cast<sd_bus *>(bus_->nativeHandle());
        return raw && !sd_bus_get_current_message(raw) ? raw : nullptr;
    }
    void pumpBus() {
        while (auto *raw = rawBus()) {
            if (sd_bus_process(raw, nullptr) <= 0) break;
        }
    }
    void clearBackend(InputContext *ic, bool focusOut = false) {
        const bool composing = !preedit_.empty();
        forget();
        auto it = contexts_.find(ic);
        if (it == contexts_.end() || !bus_) return;
        if (composing) {
            // Fcitx 4's Reset leaves Sogou's composition in place; Escape
            // drops it so a later Return or pane switch does not commit letters.
            suppressCandidates_ = true;
            suppressedCandidatesSeen_ = false;
            auto esc = icCall(it->second.path, "ProcessKeyEvent");
            esc << uint32_t(FcitxKey_Escape) << uint32_t(0) << uint32_t(0)
                << int32_t(0) << uint32_t(0);
            esc.call(200000);
            pumpBus();
            const uint64_t deadline = now(CLOCK_MONOTONIC) + 5000;
            while (!suppressedCandidatesSeen_) {
                auto *raw = rawBus();
                const uint64_t current = now(CLOCK_MONOTONIC);
                if (!raw || current >= deadline) break;
                if (sd_bus_wait(raw, deadline - current) < 0) break;
                pumpBus();
            }
            suppressCandidates_ = false;
        }
        icCall(it->second.path, "Reset").send();
        if (focusOut) icCall(it->second.path, "FocusOut").send();
    }
    int sogouCount() const { return std::min<int>(words_.size(), 9); }
    bool isSogouWord(std::string_view word) const {
        for (int i = 0; i < sogouCount(); ++i) {
            std::string_view candidate = words_[i];
            // Sogou's candidate strings end with a space.
            while (!candidate.empty() && candidate.back() == ' ') candidate.remove_suffix(1);
            if (candidate == word) return true;
        }
        return false;
    }
    // Sogou's preedit is the pinyin with its own syllable separators, after any
    // words already chosen from it: "ni'hao", or "哪吒zhi'mo" after choosing 哪吒.
    bool splitPreedit(std::string &prefix, std::string &pinyin) const {
        auto start = preedit_.find_last_not_of("abcdefghijklmnopqrstuvwxyz'");
        start = start == std::string::npos ? 0 : start + 1;
        prefix = preedit_.substr(0, start);
        if (std::any_of(prefix.begin(), prefix.end(), [](unsigned char c) { return c < 0x80; }))
            return false;
        for (char c : std::string_view(preedit_).substr(start))
            if (c != '\'') pinyin += c;
        return !pinyin.empty();
    }
    // Ask Fcitx 5's Cloud Pinyin about the pinyin being composed. The result
    // arrives later, or at once from its cache; only the latest one is used.
    void updateCloud(InputContext *ic) {
        auto *cloud = cloudpinyin();
        std::string prefix, pinyin;
        if (!cloud || !*config_.cloud || english_ || words_.empty() ||
            ic->capabilityFlags().testAny(CapabilityFlag::PasswordOrSensitive) ||
            !splitPreedit(prefix, pinyin)) {
            if (!cloud_.pinyin.empty()) {
                cloud_ = {};
                ++cloudGeneration_;
                cloudFocused_ = false;
            }
            return;
        }
        // Moving Sogou's focus re-segments the preedit; the pinyin stays.
        if (pinyin == cloud_.pinyin && prefix == cloud_.prefix) return;
        cloudFocused_ = false;
        cloud_ = {};
        cloud_.pinyin = pinyin;
        cloud_.prefix = prefix;
        cloud_.started = std::chrono::steady_clock::now();
        const auto generation = ++cloudGeneration_;
        requesting_ = true;
        cloud->call<ICloudPinyin::request>(pinyin,
            [this, generation, alive = std::weak_ptr<bool>(alive_)](const std::string &,
                                                                    const std::string &hanzi) {
                if (alive.expired() || generation != cloudGeneration_) return;
                cloud_.filled = true;
                cloud_.word = hanzi;
                cloud_.keepSlot = (hanzi.empty() || isSogouWord(hanzi)) &&
                    std::chrono::steady_clock::now() - cloud_.started > std::chrono::seconds(1);
                if (requesting_) return;
                if (auto *ic = active_.get(); ic && ic->hasFocus()) showCandidates(ic);
            });
        requesting_ = false;
    }
    bool cloudReady() const {
        return cloud_.filled && !cloud_.word.empty() && !isSogouWord(cloud_.word);
    }
    void appendCloud(CommonCandidateList &list) {
        const bool ready = cloudReady();
        // While loading the slot shows a cloud and selects nothing.
        list.append<SogouCandidate>(ready ? cloud_.word : cloudSign,
            [this](InputContext *target) { commitCloud(target); },
            ready ? cloudSign : "", cloud_.filled && !ready);
        if (ready && std::getenv("SOGOU_TEST_TRACE"))
            FCITX_INFO() << "Sogou cloud candidate: " << cloud_.word << " at " << cloudIndex_;
    }
    void showCandidates(InputContext *ic) {
        const bool inlinePreedit = ic->capabilityFlags().test(CapabilityFlag::Preedit);
        ic->inputPanel().setPreedit(inlinePreedit ? Text() : Text(preedit_));
        Text clientPreedit;
        if (inlinePreedit && !preedit_.empty()) {
            clientPreedit.append(
                preedit_,
                TextFormatFlags{TextFormatFlag::Underline, TextFormatFlag::DontCommit});
            clientPreedit.setCursor(static_cast<int>(preedit_.size()));
        }
        const bool preeditChanged =
            ic->inputPanel().clientPreedit().toString() != clientPreedit.toString();
        ic->inputPanel().setClientPreedit(clientPreedit);
        const int count = sogouCount();
        // Second place, as in Fcitx 5 Pinyin, and only on Sogou's first page.
        const bool slot = !cloud_.pinyin.empty() && page_ == 0 &&
            (!cloud_.filled || cloud_.keepSlot || cloudReady());
        cloudIndex_ = slot && count > 0 ? std::min(1, count) : -1;
        if (cloudIndex_ < 0) cloudFocused_ = false;
        if (count == 0) {
            ic->inputPanel().setCandidateList(nullptr);
        } else {
            auto list = std::make_unique<CommonCandidateList>();
            list->setPageSize(10);
            list->setLabels({"1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9.", "0."});
            list->setLayoutHint(CandidateLayoutHint::Horizontal);
            for (int i = 0; i < count; ++i) {
                if (i == cloudIndex_) appendCloud(*list);
                list->append<SogouCandidate>(words_[i], [this, i](InputContext *target) {
                    process(target, Key(static_cast<KeySym>(FcitxKey_1 + i)), false, 0);
                });
            }
            if (cloudIndex_ == count) appendCloud(*list);
            const int cursor = cloudFocused_ ? cloudIndex_
                : focus_ + (cloudIndex_ >= 0 && focus_ >= cloudIndex_ ? 1 : 0);
            list->setGlobalCursorIndex(std::clamp(cursor, 0, list->totalSize() - 1));
            ic->inputPanel().setCandidateList(std::move(list));
        }
        if (preeditChanged) ic->updatePreedit();
        ic->updateUserInterface(UserInterfaceComponent::InputPanel);
    }
    void commitCloud(InputContext *ic) {
        if (!cloudReady()) return;
        const auto text = cloud_.prefix + cloud_.word;
        // Commit while clientPreedit is still active so clients replace the
        // composition cleanly, then drop Sogou's composition, which still holds
        // the pinyin. Fcitx 4's Reset leaves it in place; Return would then
        // commit the letters.
        ic->commitString(text);
        clearBackend(ic);
        ic->inputPanel().reset();
        ic->updatePreedit();
        ic->updateUserInterface(UserInterfaceComponent::InputPanel);
        if (std::getenv("SOGOU_TEST_TRACE")) FCITX_INFO() << "Sogou cloud committed: " << text;
    }
    // Keys that act on the cloud candidate, or toggle it, instead of reaching
    // Sogou. Sogou only knows its own candidates: labels after the cloud slot
    // are one higher than Sogou's, and Sogou's focus waits before the slot
    // while the cloud candidate is focused.
    bool cloudKey(KeyEvent &event) {
        auto *ic = event.inputContext();
        const auto &key = event.key();
        if (auto *cloud = cloudpinyin();
            cloud && key.checkKeyList(cloud->call<ICloudPinyin::toggleKey>())) {
            config_.cloud.setValue(!*config_.cloud);
            safeSaveAsIni(config_, configFile);
            if (*config_.cloud) cloud->call<ICloudPinyin::resetError>();
            manager_->instance()->showCustomInputMethodInformation(
                ic, *config_.cloud ? "云拼音已开启" : "云拼音已关闭");
            updateCloud(ic);
            showCandidates(ic);
            return true;
        }
        if (cloudIndex_ < 0) return false;
        const auto &config = manager_->instance()->globalConfig();
        // Arrows pass over the slot while it is loading or only keeps its place.
        const bool ready = cloudReady();
        if (event.checkKeyList(config.defaultNextCandidate())) {
            if (cloudFocused_) {
                cloudFocused_ = false;
                process(ic, Key(FcitxKey_Down), false, event.time());
                if (cloudIndex_ < sogouCount()) focus_ = cloudIndex_;
                showCandidates(ic);
                return true;
            }
            if (!ready || focus_ != cloudIndex_ - 1) return false;
            cloudFocused_ = true;
            showCandidates(ic);
            return true;
        }
        if (event.checkKeyList(config.defaultPrevCandidate())) {
            if (cloudFocused_) {
                cloudFocused_ = false;
                showCandidates(ic);
                return true;
            }
            if (!ready || focus_ != cloudIndex_) return false;
            process(ic, Key(FcitxKey_Up), false, event.time());
            focus_ = cloudIndex_ - 1;
            cloudFocused_ = true;
            showCandidates(ic);
            return true;
        }
        if (cloudFocused_ && key.check(FcitxKey_space)) {
            commitCloud(ic);
            return true;
        }
        if (key.states().testAny(KeyStates{KeyState::Ctrl, KeyState::Alt,
                                           KeyState::Shift, KeyState::Super}))
            return false;
        int index = -1;
        if (key.sym() >= FcitxKey_1 && key.sym() <= FcitxKey_9) index = key.sym() - FcitxKey_1;
        else if (key.sym() == FcitxKey_0) index = 9;
        if (index < 0) return false;
        if (index == cloudIndex_) {
            commitCloud(ic);
            return true;
        }
        if (index > cloudIndex_ && index - 1 < sogouCount()) {
            process(ic, Key(static_cast<KeySym>(FcitxKey_1 + index - 1)), false, event.time());
            return true;
        }
        return false;
    }
    // sogou-backend records its own path here for "--settings".
    static std::string launcher() {
        std::string dir;
        if (const char *file = std::getenv("SOGOU_BUS_ADDRESS_FILE")) {
            dir = file;
            dir.erase(dir.rfind('/') + 1);
        } else if (const char *runtime = std::getenv("XDG_RUNTIME_DIR")) {
            dir = std::string(runtime) + "/sogou-bridge/";
        }
        std::ifstream stream(dir + "launcher");
        std::string path;
        std::getline(stream, path);
        return path;
    }
    // While candidates are shown, Fcitx 5's candidate hotkeys (Left/Right and
    // Up/Down on this desktop) are mapped to Sogou's own keys: Up/Down move
    // the focused candidate, Page Up/Down change the page.
    Key sogouKey(const KeyEvent &event) const {
        if (!event.inputContext()->inputPanel().candidateList()) return event.rawKey();
        const auto &config = manager_->instance()->globalConfig();
        if (event.checkKeyList(config.defaultPrevCandidate())) return Key(FcitxKey_Up);
        if (event.checkKeyList(config.defaultNextCandidate())) return Key(FcitxKey_Down);
        if (event.checkKeyList(config.defaultPrevPage())) return Key(FcitxKey_Page_Up);
        if (event.checkKeyList(config.defaultNextPage())) return Key(FcitxKey_Page_Down);
        return event.rawKey();
    }
    bool process(InputContext *ic, Key key, bool release, uint32_t time) {
        for (int attempt = 0; attempt < 2; ++attempt) {
            auto *ctx = ensure(ic);
            if (!ctx) return false;
            PendingKey state{ic, key, release,
                             !preedit_.empty() || !ic->inputPanel().clientPreedit().empty()};
            struct Guard {
                PendingKey *&slot;
                PendingKey *previous;
                ~Guard() { slot = previous; }
            } guard{pending_, pending_};
            pending_ = &state;
            auto msg = icCall(ctx->path, "ProcessKeyEvent");
            msg << uint32_t(key.sym()) << uint32_t(key.code()) << uint32_t(key.states())
                << int32_t(release ? 1 : 0) << time;
            auto reply = msg.call(1000000);
            if (!reply.isError()) {
                int32_t handled = 0;
                reply >> handled;
                const bool accepted = reply && handled;
                // sd_bus_call queues incoming signals without dispatching them,
                // and Fcitx 4 emits CommitString right after ProcessKeyEvent's
                // reply. Drain them here so Fcitx 5's ProcessKeyEventBatch
                // delivers preedit and commits synchronously with the keystroke.
                pumpBus();
                const auto needMore = [&] {
                    if (state.deferredClear && !state.sawCommit) return true;
                    if (release &&
                        (key.sym() == FcitxKey_Shift_L || key.sym() == FcitxKey_Shift_R) &&
                        state.hadPreedit && !state.sawCommit)
                        return true;
                    if (accepted && !release && !key.isModifier() &&
                        !state.sawCandidates && !state.sawCommit &&
                        !state.sawForward && !state.sawMode)
                        return true;
                    return false;
                };
                const uint64_t started = now(CLOCK_MONOTONIC);
                while (needMore()) {
                    auto *raw = rawBus();
                    const uint64_t budgetUs =
                        (state.deferredClear || (release && state.hadPreedit)) ? 25000 : 5000;
                    const uint64_t deadline = started + budgetUs;
                    const uint64_t current = now(CLOCK_MONOTONIC);
                    if (!raw || current >= deadline) break;
                    if (sd_bus_wait(raw, deadline - current) < 0) break;
                    pumpBus();
                }
                if (state.deferredClear) {
                    state.deferredClear = false;
                    showCandidates(ic);
                }
                return accepted;
            }
            const auto error = reply.errorName();
            // UnknownObject/Method proves that this key was not processed.
            if (error != "org.freedesktop.DBus.Error.UnknownMethod" &&
                error != "org.freedesktop.DBus.Error.UnknownObject") {
                // Do not resend timed-out keys: they may already have committed.
                FCITX_WARN() << "Sogou backend: " << reply.errorMessage();
                return false;
            }
            contexts_.erase(ic);
        }
        return false;
    }
    bool mode(dbus::Message &msg) {
        // Sogou keeps its Chinese/English mode inside the engine; Fcitx 4
        // stays active. The hook reports it so Fcitx 5 can show it.
        bool english = false;
        msg >> english;
        if (!msg) return false;
        if (pending_) pending_->sawMode = true;
        if (english == english_) return false;
        english_ = english;
        if (auto *ic = active_.get(); ic && ic->hasFocus()) {
            ic->updateUserInterface(UserInterfaceComponent::StatusArea);
            manager_->instance()->showInputMethodInformation(ic);
        }
        return true;
    }
    bool focus(Context &ctx) {
        // Keep all initialization messages on the same ordered connection.
        // A slow FocusIn must not prevent EnableIC from ever being sent.
        if (!icCall(ctx.path, "FocusIn").send()) return false;
        if (!icCall(ctx.path, "EnableIC").send()) return false;
        auto msg = bus_->createMethodCall(service_.c_str(), "/inputmethod", imInterface, "SetCurrentIM");
        msg << std::string("sogoupinyin");
        return msg.send();
    }
    dbus::Message icCall(const std::string &path, const char *method) {
        return bus_->createMethodCall(service_.c_str(), path.c_str(), icInterface, method);
    }
    Context *ensure(InputContext *ic) {
        const char *file = std::getenv("SOGOU_BUS_ADDRESS_FILE");
        std::string filename;
        if (file) filename = file;
        else if (const char *runtime = std::getenv("XDG_RUNTIME_DIR"))
            filename = std::string(runtime) + "/sogou-bridge/address";
        std::ifstream stream(filename);
        std::string address, service;
        std::getline(stream, address);
        std::getline(stream, service);
        if (address.empty() || service.empty()) return nullptr;
        if (bus_ && (!bus_->isOpen() || address != address_ || service != service_)) {
            modeMatch_.reset(); candidatesMatch_.reset(); ownerMatch_.reset(); match_.reset();
            bus_->detachEventLoop(); bus_.reset(); contexts_.clear();
            // A restarted Sogou starts in Chinese mode and reports any change.
            english_ = false;
        }
        if (!bus_) {
            address_ = address;
            service_ = service;
            try {
                bus_ = std::make_unique<dbus::Bus>(address);
                bus_->attachEventLoop(manager_->eventLoop());
                match_ = bus_->addMatch(dbus::MatchRule(service_, "", icInterface),
                    [this](dbus::Message &msg) { return signal(msg); });
                candidatesMatch_ = bus_->addMatch(dbus::MatchRule("org.sogou.Bridge", "/org/sogou/Bridge", "org.sogou.Bridge", "Candidates"),
                    [this](dbus::Message &msg) { return candidates(msg); });
                modeMatch_ = bus_->addMatch(dbus::MatchRule("org.sogou.Bridge", "/org/sogou/Bridge", "org.sogou.Bridge", "Mode"),
                    [this](dbus::Message &msg) { return mode(msg); });
                ownerMatch_ = bus_->addMatch(dbus::MatchRule("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus", "NameOwnerChanged", {service_}),
                    [this](dbus::Message &msg) {
                        // Only a lost or replaced owner invalidates contexts. The
                        // address file is written before Fcitx 4 takes its name, so
                        // the first acquisition can arrive after a context was
                        // already created for it; clearing then dropped a commit.
                        std::string name, oldOwner, newOwner;
                        msg >> name >> oldOwner >> newOwner;
                        if (!msg || !oldOwner.empty()) contexts_.clear();
                        return true;
                    });
            } catch (const std::exception &e) {
                FCITX_WARN() << "Sogou bridge: " << e.what();
                bus_.reset();
                return nullptr;
            }
        }
        for (auto it = contexts_.begin(); it != contexts_.end();) {
            if (!it->second.reference.isValid()) {
                icCall(it->second.path, "DestroyIC").send();
                it = contexts_.erase(it);
            } else ++it;
        }
        if (auto it = contexts_.find(ic); it != contexts_.end()) return &it->second;
        auto msg = bus_->createMethodCall(service_.c_str(), "/inputmethod", imInterface, "CreateICv3");
        // The backend has its own PID namespace. A host PID is not meaningful
        // there: Fcitx 4 would reap this context when another window opens.
        // PID 0 disables that check; D-Bus ownership and our weak refs own it.
        msg << std::string("fcitx5-sogou-bridge") << int32_t(0);
        auto reply = msg.call(500000);
        if (reply.isError()) {
            FCITX_WARN() << "Sogou CreateIC: " << reply.errorMessage();
            return nullptr;
        }
        int32_t id = -1; bool enabled = false; uint32_t a,b,c,d;
        reply >> id >> enabled >> a >> b >> c >> d;
        if (!reply || id < 0) return nullptr;
        auto &ctx = contexts_[ic];
        ctx = {ic->watch(), "/inputcontext_" + std::to_string(id)};
        auto capacity = icCall(ctx.path, "SetCapacity");
        capacity << uint32_t((1 << 1) | (1 << 2) | (1 << 4));
        capacity.call(300000);
        focus(ctx);
        return &ctx;
    }
    bool candidates(dbus::Message &msg) {
        std::string preedit;
        std::vector<std::string> words;
        int32_t focus = 0, page = 0;
        msg >> preedit >> words >> focus;
        // Hooks before 0.3.0 do not send the page.
        if (msg.signature() == "sasii") msg >> page;
        if (!msg) return false;
        if (suppressCandidates_) {
            suppressedCandidatesSeen_ = true;
            return true;
        }
        auto *ic = active_.get();
        if (!ic || !ic->hasFocus()) return false;
        const bool wasComposing =
            !preedit_.empty() || !ic->inputPanel().clientPreedit().empty();
        preedit_ = std::move(preedit);
        words_ = std::move(words);
        focus_ = focus;
        page_ = page;
        updateCloud(ic);
        if (pending_ && pending_->ic == ic && preedit_.empty() && words_.empty() &&
            wasComposing && !pending_->sawCommit &&
            pending_->key.sym() != FcitxKey_Escape &&
            pending_->key.sym() != FcitxKey_BackSpace) {
            // Candidates("", []) on org.sogou.Bridge arrives ahead of Fcitx 4's
            // CommitString. Keep clientPreedit in place until CommitString runs
            // so clients replace the active composition instead of ending it empty.
            pending_->sawCandidates = true;
            pending_->deferredClear = true;
        } else {
            if (pending_ && pending_->ic == ic) {
                pending_->sawCandidates = true;
                pending_->deferredClear = false;
            }
            showCandidates(ic);
        }
        if (std::getenv("SOGOU_TEST_TRACE")) FCITX_INFO() << "Sogou native candidates: " << words_.size() << " focus " << focus_ << " page " << page_ << " preedit " << preedit_;
        return true;
    }
    bool signal(dbus::Message &msg) {
        InputContext *ic = nullptr;
        for (auto &[_, ctx] : contexts_)
            if (ctx.path == msg.path()) { ic = ctx.reference.get(); break; }
        if (!ic) return false;
        if (msg.member() == "CommitString") {
            std::string text; msg >> text;
            if (msg) {
                const bool keepNewPreedit =
                    pending_ && pending_->ic == ic && pending_->sawCandidates && !preedit_.empty();
                if (pending_ && pending_->ic == ic) {
                    pending_->sawCommit = true;
                    pending_->deferredClear = false;
                }
                ic->commitString(text);
                if (keepNewPreedit) {
                    showCandidates(ic);
                } else {
                    forget();
                    ic->inputPanel().reset();
                    ic->updatePreedit();
                    ic->updateUserInterface(UserInterfaceComponent::InputPanel);
                }
            }
        } else if (msg.member() == "UpdateFormattedPreedit") {
            std::vector<dbus::DBusStruct<std::string, int32_t>> parts;
            int32_t cursor = 0; msg >> parts >> cursor;
            if (!msg) return false;
            // Fcitx 4 only emits an empty array on IC setup/reset; ignore it so
            // it cannot clobber the preedit reported by org.sogou.Bridge.
            if (!parts.empty()) {
                Text text;
                for (const auto &part : parts)
                    text.append(std::get<0>(part.data()),
                                TextFormatFlags{TextFormatFlag::Underline, TextFormatFlag::DontCommit});
                text.setCursor(cursor);
                ic->inputPanel().setClientPreedit(text);
                ic->updatePreedit();
            }
        } else if (msg.member() == "ForwardKey") {
            uint32_t sym=0, state=0; int32_t type=0; msg >> sym >> state >> type;
            if (msg) {
                if (pending_ && pending_->ic == ic) pending_->sawForward = true;
                ic->forwardKey(Key(static_cast<KeySym>(sym), KeyStates(state)), type != 0);
            }
        }
        return true;
    }
    AddonManager *manager_;
    std::unique_ptr<dbus::Bus> bus_;
    std::unique_ptr<EventSourceTime> reconnectTimer_;
    std::unique_ptr<HandlerTableEntry<EventHandler>> shiftWatcher_;
    SimpleAction settingsAction_;
    BridgeConfig config_;
    mutable std::unique_ptr<BridgeConfig> settingsConfig_;
    std::unique_ptr<dbus::Slot> match_;
    std::unique_ptr<dbus::Slot> candidatesMatch_, modeMatch_, ownerMatch_;
    TrackableObjectReference<InputContext> active_;
    bool english_ = false;
    std::string service_, address_;
    std::map<InputContext *, Context> contexts_;
    // Sogou's last candidate update.
    std::string preedit_;
    std::vector<std::string> words_;
    int32_t focus_ = 0, page_ = 0;
    Cloud cloud_;
    uint64_t cloudGeneration_ = 0;
    bool requesting_ = false, cloudFocused_ = false;
    // Position of the cloud slot in the shown list, or -1.
    int cloudIndex_ = -1;
    PendingKey *pending_ = nullptr;
    bool suppressCandidates_ = false, suppressedCandidatesSeen_ = false;
    std::shared_ptr<bool> alive_ = std::make_shared<bool>(true);
};
class Factory final : public AddonFactory {
    AddonInstance *create(AddonManager *manager) override { return new SogouBridge(manager); }
};
}
FCITX_ADDON_FACTORY(Factory)
