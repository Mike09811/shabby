I have redesigned the application UI according to your requirements.

**Key Changes:**

1.  **Main Navigation**:
    *   Created a `MainScreen` with a Bottom Navigation Bar containing 3 tabs: **加速 (Accelerate)**, **会员 (Membership)**, **我的 (Profile)**.
    *   Updated `main.dart` to use `MainScreen` as the entry point.

2.  **Accelerate Tab (Home)**:
    *   Refactored the Home screen layout.
    *   **Header**: Left-aligned "ClashMi" logo, Right-aligned Mode Switch (Rule/Global).
    *   **Customer Service**: Added a "客服" button.
    *   **Center**: Large circular "Start" button that indicates status (Connected/Disconnected/Connecting).
    *   **Node Selector**: Displays the current node name and allows switching.
    *   **Banner**: Added a marketing banner at the bottom.

3.  **Membership Tab**:
    *   Created `MembershipScreen`.
    *   Displays membership plans: Weekly, Monthly, Quarterly, Half-Yearly, Yearly cards.

4.  **Profile Tab**:
    *   Created `ProfileScreen`.
    *   **Header**: User avatar (clickable to login), User ID.
    *   **Membership Card**: Displays VIP status.
    *   **Menu**: "Software Anti-loss", "Online Customer Service", "Feedback", "Change Password", "Logout".
    *   Added a basic `LoginScreen` for navigation.

5.  **Theme**:
    *   The app uses a dark theme with blue accents (`Colors.blue`, `Colors.black`, `Colors.grey[900]`) to match the "Black & Blue" requirement.

**Files Created/Modified:**
*   `lib/screens/main_screen.dart` (New)
*   `lib/screens/membership_screen.dart` (New)
*   `lib/screens/profile_screen.dart` (New)
*   `lib/screens/login_screen.dart` (New)
*   `lib/screens/home_screen.dart` (Modified layout)
*   `lib/screens/home_screen_widgets.dart` (Rewrote widget for new UI)
*   `lib/main.dart` (Updated entry point)

You can now run the app to see the new UI.
