{ pkgs, ... }:
let
  patch = ''
    --- a/window/src/os/wayland/window.rs
    +++ b/window/src/os/wayland/window.rs
    @@ -145,7 +145,6 @@ pub struct WaylandWindowInner {
         key_repeat: Option<(u32, Arc<Mutex<KeyRepeatState>>)>,
         pending_event: Arc<Mutex<PendingEvent>>,
         pending_mouse: Arc<Mutex<PendingMouse>>,
    -    pending_first_configure: Option<async_channel::Sender<()>>,
         frame_callback: Option<Main<WlCallback>>,
         invalidated: bool,
         font_config: Rc<FontConfiguration>,
    @@ -263,8 +262,6 @@ impl WaylandWindow {
             let window_id = conn.next_window_id();
             let pending_event = Arc::new(Mutex::new(PendingEvent::default()));
     
    -        let (pending_first_configure, wait_configure) = async_channel::bounded(1);
    -
             let surface = conn.environment.create_surface_with_scale_callback({
                 let pending_event = Arc::clone(&pending_event);
                 move |dpi, surface, _dispatch_data| {
    @@ -372,7 +369,6 @@ impl WaylandWindow {
                 leds: KeyboardLedStatus::empty(),
                 pending_event,
                 pending_mouse,
    -            pending_first_configure: Some(pending_first_configure),
                 frame_callback: None,
                 title: None,
                 gl_state: None,
    @@ -389,8 +385,6 @@ impl WaylandWindow {
     
             conn.windows.borrow_mut().insert(window_id, inner.clone());
     
    -        wait_configure.recv().await?;
    -
             Ok(window_handle)
         }
     }
    @@ -747,12 +741,6 @@ impl WaylandWindowInner {
             if pending.refresh_decorations && self.window.is_some() {
                 self.refresh_frame();
             }
    -        if pending.had_configure_event && self.window.is_some() {
    -            if let Some(notify) = self.pending_first_configure.take() {
    -                // Allow window creation to complete
    -                notify.try_send(()).ok();
    -            }
    -        }
         }
     
         fn refresh_frame(&mut self) {
  '';
in
pkgs.wezterm.overrideAttrs (prev: {
  patches = prev.patches or [ ] ++ [ (pkgs.writeText "remove_first_configure.patch" patch) ];
})
