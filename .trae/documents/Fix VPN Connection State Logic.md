I have fixed the issue where the VPN connection would not start (or appeared not to start) after adding a node.

**Reason:**
The simulated VPN core (stubbed for iOS simulator/preview) was stateless. When you clicked "Connect", it returned "Success" immediately but didn't update the internal state to "Connected", causing the UI to revert to "Disconnected" instantly.

**Fix:**
I updated `packages/libclash-vpn-service/lib/vpn_service.dart` to maintain the connection state (`_currentState`). Now, when you click the "Start" button:
1.  The service transitions to `FlutterVpnServiceState.connected`.
2.  The UI correctly updates to show the "Connected" state (Blue button, "已连接").
3.  The "Stop" button will correctly transition it back to `disconnected`.

You should now be able to add a node and see the connection status change when you tap the power button.
