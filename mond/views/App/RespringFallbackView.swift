//
//  RespringFallbackView.swift
//  mond
//

import SwiftUI
import PartyUI

struct RespringFallbackView: View {
    @State private var showView = false
    
    static func show() {
        // This will be triggered after respring attempt fails
        NotificationCenter.default.post(name: NSNotification.Name("ShowRespringFallback"), object: nil)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "arrow.clockwise.circle")
                .font(.system(size: 60))
                .foregroundStyle(.orange)
            
            Text("Respring Not Available")
                .font(.title2)
                .bold()
            
            Text("On iOS 27 without jailbreak, a true respring is not possible. You need to reboot your device for tweaks to take effect.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            
            Button {
                // Just close the app - user will manually reboot
                exit(0)
            } label: {
                Text("Close App & Reboot Manually")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemBackground))
                .shadow(radius: 10)
        )
        .padding(40)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowRespringFallback"))) { _ in
            showView = true
        }
    }
}