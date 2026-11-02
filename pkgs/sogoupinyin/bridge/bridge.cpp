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
#include <fcitx-config/option.h>
#include <fcitx-utils/dbus/bus.h>
#include <fcitx-utils/log.h>
#include <fcitx-utils/misc.h>
#include <algorithm>
#include <cstdlib>
#include <fstream>
#include <map>
#include <functional>
#include <unistd.h>

using namespace fcitx;
namespace {
constexpr auto imInterface = "org.fcitx.Fcitx.InputMethod";
constexpr auto icInterface = "org.fcitx.Fcitx.InputContext";
struct Context {
    TrackableObjectReference<InputContext> reference;
    std::string path;
};
class SogouCandidate final : public CandidateWord {
public:
    SogouCandidate(const std::string &word, std::function<void(InputContext *)> select)
        : CandidateWord(Text(word)), select_(std::move(select)) {}
    void select(InputContext *ic) const override { select_(ic); }
private:
    std::function<void(InputContext *)> select_;
};
// Fcitx 5's settings show this option as a button that runs the command, the
// same way Mozc offers its configuration tool.
class SettingsConfig final : public Configuration {
public:
    explicit SettingsConfig(std::string command)
        : settings_(this, "SogouSettings", "搜狗输入法设置", std::move(command)) {}
    const char *typeName() const override { return "SogouBridgeConfig"; }
private:
    ExternalOption settings_;
};

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
        event.inputContext()->statusArea().addAction(StatusGroup::InputMethod, &settingsAction_);
        auto *ctx = ensure(event.inputContext());
        if (!ctx) return;
        if (!focus(*ctx)) {
            contexts_.erase(event.inputContext());
            if (auto *fresh = ensure(event.inputContext())) focus(*fresh);
        }
    }
    void deactivate(const InputMethodEntry &, InputContextEvent &event) override {
        if (active_.get() == event.inputContext()) active_.unwatch();
        auto it = contexts_.find(event.inputContext());
        if (it != contexts_.end() && bus_) {
            icCall(it->second.path, "Reset").send();
            icCall(it->second.path, "FocusOut").send();
        }
        event.inputContext()->inputPanel().reset();
        event.inputContext()->updatePreedit();
        event.inputContext()->updateUserInterface(UserInterfaceComponent::InputPanel);
    }
    void reset(const InputMethodEntry &, InputContextEvent &event) override {
        auto it = contexts_.find(event.inputContext());
        if (it != contexts_.end() && bus_) icCall(it->second.path, "Reset").send();
        event.inputContext()->inputPanel().reset();
        event.inputContext()->updatePreedit();
        event.inputContext()->updateUserInterface(UserInterfaceComponent::InputPanel);
    }
    void keyEvent(const InputMethodEntry &, KeyEvent &event) override {
        active_ = event.inputContext()->watch();
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
        settingsConfig_ = std::make_unique<SettingsConfig>(path.empty() ? "" : path + " --settings");
        return settingsConfig_.get();
    }
    void setConfigForInputMethod(const InputMethodEntry &, const RawConfig &) override {}
private:
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
            auto msg = icCall(ctx->path, "ProcessKeyEvent");
            msg << uint32_t(key.sym()) << uint32_t(key.code()) << uint32_t(key.states())
                << int32_t(release ? 1 : 0) << time;
            auto reply = msg.call(1000000);
            if (!reply.isError()) {
                int32_t handled = 0;
                reply >> handled;
                return reply && handled;
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
        if (!msg || english == english_) return false;
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
        auto *ic = active_.get();
        if (!ic || !ic->hasFocus()) return false;
        std::string preedit;
        std::vector<std::string> words;
        int32_t focus = 0;
        msg >> preedit >> words >> focus;
        if (!msg) return false;
        ic->inputPanel().setPreedit(Text(preedit));
        if (words.empty()) {
            ic->inputPanel().setCandidateList(nullptr);
        } else {
            auto list = std::make_unique<CommonCandidateList>();
            list->setPageSize(9);
            list->setLabels({"1.", "2.", "3.", "4.", "5.", "6.", "7.", "8.", "9."});
            list->setLayoutHint(CandidateLayoutHint::Horizontal);
            for (size_t i = 0; i < words.size() && i < 9; ++i) {
                list->append<SogouCandidate>(words[i], [this, i](InputContext *target) {
                    KeyEvent key(target, Key(static_cast<KeySym>(FcitxKey_1 + i)));
                    keyEvent(InputMethodEntry("sogou", "Sogou", "zh_CN", "sogoubridge"), key);
                });
            }
            list->setGlobalCursorIndex(std::clamp<int>(focus, 0, list->totalSize() - 1));
            ic->inputPanel().setCandidateList(std::move(list));
        }
        ic->updateUserInterface(UserInterfaceComponent::InputPanel);
        if (std::getenv("SOGOU_TEST_TRACE")) FCITX_INFO() << "Sogou native candidates: " << words.size() << " focus " << focus;
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
                ic->commitString(text);
                ic->inputPanel().reset();
                ic->updatePreedit();
                ic->updateUserInterface(UserInterfaceComponent::InputPanel);
            }
        } else if (msg.member() == "UpdateFormattedPreedit") {
            std::vector<dbus::DBusStruct<std::string, int32_t>> parts;
            int32_t cursor = 0; msg >> parts >> cursor;
            if (!msg) return false;
            Text text;
            for (const auto &part : parts) text.append(std::get<0>(part.data()), TextFormatFlag::Underline);
            text.setCursor(cursor);
            ic->inputPanel().setClientPreedit(text);
            ic->updatePreedit();
        } else if (msg.member() == "ForwardKey") {
            uint32_t sym=0, state=0; int32_t type=0; msg >> sym >> state >> type;
            if (msg) ic->forwardKey(Key(static_cast<KeySym>(sym), KeyStates(state)), type != 0);
        }
        return true;
    }
    AddonManager *manager_;
    std::unique_ptr<dbus::Bus> bus_;
    std::unique_ptr<EventSourceTime> reconnectTimer_;
    std::unique_ptr<HandlerTableEntry<EventHandler>> shiftWatcher_;
    SimpleAction settingsAction_;
    mutable std::unique_ptr<SettingsConfig> settingsConfig_;
    std::unique_ptr<dbus::Slot> match_;
    std::unique_ptr<dbus::Slot> candidatesMatch_, modeMatch_, ownerMatch_;
    TrackableObjectReference<InputContext> active_;
    bool english_ = false;
    std::string service_, address_;
    std::map<InputContext *, Context> contexts_;
};
class Factory final : public AddonFactory {
    AddonInstance *create(AddonManager *manager) override { return new SogouBridge(manager); }
};
}
FCITX_ADDON_FACTORY(Factory)
