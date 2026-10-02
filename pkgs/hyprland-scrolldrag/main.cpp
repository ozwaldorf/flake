// Drags the scrolling layout with the pointer by driving the scroll move
// gesture, so a drag shares the swipe's momentum and snapping on release.

#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/event/EventBus.hpp>
#include <hyprland/src/managers/input/InputManager.hpp>
#include <hyprland/src/managers/input/trackpad/gestures/ScrollMoveGesture.hpp>

#include <chrono>

namespace {
    HANDLE g_handle = nullptr;

    struct {
        CScrollMoveTrackpadGesture gesture;
        CHyprSignalListener        move;
        CHyprSignalListener        button;
        Vector2D                   last;
        uint32_t                   lastMoveMs = 0;
    } g_drag;

    // a release after the pointer rested this long carries no momentum
    constexpr uint32_t DRAG_REST_MS = 50;

    uint32_t           nowMs() {
        return static_cast<uint32_t>(std::chrono::duration_cast<std::chrono::milliseconds>(std::chrono::steady_clock::now().time_since_epoch()).count());
    }

    void dragBegin() {
        if (g_drag.move)
            return;

        g_drag.last       = g_pInputManager->getMouseCoordsInternal();
        g_drag.lastMoveMs = nowMs();

        const IPointer::SSwipeUpdateEvent SWIPE = {.timeMs = g_drag.lastMoveMs};
        g_drag.gesture.begin({.swipe = &SWIPE, .direction = TRACKPAD_GESTURE_DIR_HORIZONTAL});

        // motion is swallowed so clients see no hover or focus changes mid drag
        g_drag.move = Event::bus()->m_events.input.mouse.move.listen([](Vector2D pos, Event::SCallbackInfo& info) {
            info.cancelled = true;

            const IPointer::SSwipeUpdateEvent SWIPE = {.timeMs = nowMs(), .delta = {pos.x - g_drag.last.x, 0.0}};
            g_drag.last                             = pos;
            g_drag.lastMoveMs                       = SWIPE.timeMs;
            g_drag.gesture.update({.swipe = &SWIPE, .direction = TRACKPAD_GESTURE_DIR_HORIZONTAL});
        });

        g_drag.button = Event::bus()->m_events.input.mouse.button.listen([](IPointer::SButtonEvent e, Event::SCallbackInfo&) {
            if (e.state != WL_POINTER_BUTTON_STATE_RELEASED)
                return;

            // drop the motion listener first, ending the gesture may warp the cursor
            g_drag.move.reset();

            const auto                     NOW   = nowMs();
            const IPointer::SSwipeEndEvent SWIPE = {.timeMs = NOW, .cancelled = NOW - g_drag.lastMoveMs > DRAG_REST_MS};
            g_drag.gesture.end({.swipe = &SWIPE, .direction = TRACKPAD_GESTURE_DIR_HORIZONTAL});

            g_drag.button.reset();
        });
    }

    // hl.plugin.scrolldrag.start(), follows the pointer until the next button release
    int luaStart(lua_State*) {
        dragBegin();
        return 0;
    }
}

APICALL EXPORT std::string PLUGIN_API_VERSION() {
    return HYPRLAND_API_VERSION;
}

APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE handle) {
    g_handle = handle;

    if (!HyprlandAPI::addLuaFunction(g_handle, "scrolldrag", "start", luaStart))
        HyprlandAPI::addNotification(g_handle, "[scrolldrag] failed to register hl.plugin.scrolldrag.start", CHyprColor(1.0, 0.2, 0.2, 1.0), 5000);

    return {
        .name        = "scrolldrag",
        .description = "Drag the scrolling layout with the pointer",
        .author      = "ozwaldorf",
        .version     = "0.1.0",
    };
}

APICALL EXPORT void PLUGIN_EXIT() {
    g_drag.move.reset();
    g_drag.button.reset();
    HyprlandAPI::removeLuaFunction(g_handle, "scrolldrag", "start");
}
