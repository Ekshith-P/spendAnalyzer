import SwiftUI

struct LockScreenView: View {
    // Reads the locked state directly from the device's hard drive
    @AppStorage("isAppLocked") private var isAppLocked: Bool = true
    
    @State private var pinInput = ""
    @State private var showErrorMessage = false
    @FocusState private var isKeyboardFocused: Bool
    
    var body: some View {
        VStack(spacing: 30) {
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.red)
            
            Text("App Locked")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Too many incorrect attempts.\nEnter PIN to unlock your data.")
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            SecureField("Enter PIN", text: $pinInput)
                .keyboardType(.numberPad)
                .focused($isKeyboardFocused)
                .padding()
                .background(Color(.systemGray6).opacity(0.3))
                .cornerRadius(10)
                .foregroundColor(.white)
                .padding(.horizontal, 40)
            
            if showErrorMessage {
                Text("Incorrect PIN")
                    .foregroundColor(.red)
                    .font(.callout)
            }
            
            Button(action: unlockApp) {
                Text("Unlock App")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(pinInput.count > 0 ? Color.white : Color.white.opacity(0.1))
                    .foregroundColor(pinInput.count > 0 ? .black : .gray)
                    .cornerRadius(15)
            }
            .disabled(pinInput.isEmpty)
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            isKeyboardFocused = true
        }
    }
    
    private func unlockApp() {
        if pinInput == "0495" {
            // Unlocks the app permanently until the next security breach
            isAppLocked = false
            pinInput = ""
            showErrorMessage = false
        } else {
            showErrorMessage = true
            pinInput = ""
            // Vibrate on error
            UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
    }
}
