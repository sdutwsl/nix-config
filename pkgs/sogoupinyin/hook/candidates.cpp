#include <dbus/dbus.h>
#include <dlfcn.h>
#include <algorithm>
#include <cstring>
#include <string>
#include <vector>

namespace {
template<class T> T symbol(const char *name) { return reinterpret_cast<T>(dlsym(RTLD_NEXT, name)); }
DBusConnection *connection() {
    static DBusConnection *bus = [] {
        DBusError error; dbus_error_init(&error);
        auto *c = dbus_bus_get_private(DBUS_BUS_SESSION, &error);
        if (c) {
            dbus_connection_set_exit_on_disconnect(c, false);
            dbus_bus_request_name(c, "org.sogou.Bridge", DBUS_NAME_FLAG_DO_NOT_QUEUE, &error);
        }
        dbus_error_free(&error);
        return c;
    }();
    return bus;
}
void publish(bool clear = false) {
    static auto getIme = symbol<void *(*)()>("GetSogouIme");
    static auto count = symbol<unsigned (*)(void *)>("_ZN10t_sogouIme12GetCandCountEv");
    static auto cand = symbol<const char *(*)(void *, unsigned)>("_ZN10t_sogouIme10GetCandStrEj");
    static auto comp = symbol<const char *(*)(void *)>("_ZN10t_sogouIme10GetCompStrEv");
    static auto info = symbol<int (*)(void *, unsigned)>("_ZN10t_sogouIme7GetInfoEj");
    if (!getIme || !count || !cand || !comp || !info) return;
    auto *ime = getIme();
    if (!ime) return;
    std::vector<std::string> words;
    // Found like the mode below: GetInfo(109) is the focused candidate on the
    // current page, moved by Up/Down (102 is the page number).
    dbus_int32_t focus = clear ? 0 : info(ime, 109);
    const char *preedit = clear ? "" : comp(ime);
    if (!preedit) preedit = "";
    if (!clear) {
        unsigned n = std::min(count(ime), 9u);
        for (unsigned i = 0; i < n; ++i) {
            auto *s = cand(ime, i);
            std::string word = s ? s : "";
            // The engine includes its own selection number in this accessor.
            const auto label = std::to_string(i + 1) + ".";
            if (word.compare(0, label.size(), label) == 0) {
                word.erase(0, label.size());
                while (!word.empty() && word.front() == ' ') word.erase(0, 1);
            }
            words.emplace_back(std::move(word));
        }
    }
    static std::string previousPreedit;
    static std::vector<std::string> previousWords;
    static dbus_int32_t previousFocus = 0;
    static bool initialized = false;
    if (initialized && previousPreedit == preedit && previousWords == words &&
        previousFocus == focus)
        return;
    previousPreedit = preedit;
    previousWords = words;
    previousFocus = focus;
    initialized = true;
    auto *bus = connection();
    if (!bus || !dbus_connection_get_is_connected(bus)) return;
    auto *msg = dbus_message_new_signal("/org/sogou/Bridge", "org.sogou.Bridge", "Candidates");
    if (!msg) return;
    DBusMessageIter iter, array;
    dbus_message_iter_init_append(msg, &iter);
    dbus_message_iter_append_basic(&iter, DBUS_TYPE_STRING, &preedit);
    dbus_message_iter_open_container(&iter, DBUS_TYPE_ARRAY, "s", &array);
    for (auto &s : words) {
        const char *word = s.c_str();
        dbus_message_iter_append_basic(&array, DBUS_TYPE_STRING, &word);
    }
    dbus_message_iter_close_container(&iter, &array);
    dbus_message_iter_append_basic(&iter, DBUS_TYPE_INT32, &focus);
    dbus_connection_send(bus, msg, nullptr);
    dbus_connection_flush(bus);
    dbus_message_unref(msg);
}
void publishMode() {
    static auto getIme = symbol<void *(*)()>("GetSogouIme");
    static auto info = symbol<int (*)(void *, unsigned)>("_ZN10t_sogouIme7GetInfoEj");
    if (!getIme || !info) return;
    auto *ime = getIme();
    if (!ime) return;
    // Found by diffing GetInfo(0..399) around a Shift tap: 106 is 1 in Chinese
    // mode and 0 in English mode (108 is the punctuation mode, Ctrl+.).
    dbus_bool_t english = info(ime, 106) == 0;
    static int previous = -1;
    if (previous == static_cast<int>(english)) return;
    previous = english;
    auto *bus = connection();
    if (!bus || !dbus_connection_get_is_connected(bus)) return;
    auto *msg = dbus_message_new_signal("/org/sogou/Bridge", "org.sogou.Bridge", "Mode");
    if (!msg) return;
    dbus_message_append_args(msg, DBUS_TYPE_BOOLEAN, &english, DBUS_TYPE_INVALID);
    dbus_connection_send(bus, msg, nullptr);
    dbus_connection_flush(bus);
    dbus_message_unref(msg);
}
}

// These exported C++ entry points belong to the supplied 4.2.1.145 binary.
// Interpose only its UI boundary; Sogou still performs composition and selection.
extern "C" int update(void *self) asm("_ZN10t_sogouIme9UpdateImeEv");
extern "C" int update(void *self) {
    static auto original = symbol<int (*)(void *)>("_ZN10t_sogouIme9UpdateImeEv");
    int result = original ? original(self) : 0;
    publish();
    return result;
}
extern "C" int showComp(void *) asm("_ZN11t_uiWrapper8ShowCompEv");
extern "C" int showComp(void *) { publish(); return 1; }
extern "C" int updateComp(void *) asm("_ZN11t_uiWrapper10UpdateCompEv");
extern "C" int updateComp(void *) { publish(); return 1; }
extern "C" int showPreedit(void *) asm("_ZN11t_uiWrapper11ShowPreeditEv");
extern "C" int showPreedit(void *) { return 1; }
extern "C" int updateStatus(void *self) asm("_ZN11t_uiWrapper12UpdateStatusEv");
extern "C" int updateStatus(void *self) {
    static auto original = symbol<int (*)(void *)>("_ZN11t_uiWrapper12UpdateStatusEv");
    int result = original ? original(self) : 0;
    publishMode();
    return result;
}
extern "C" int hideComp(void *) asm("_ZN11t_uiWrapper8HideCompEv");
extern "C" int hideComp(void *) { publish(true); return 1; }
