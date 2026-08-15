//
//  ContentView.swift
//  mond
//
//  Created by ruter on 17.07.26.
//

import SwiftUI
import PartyUI

struct ContentView: View {
    @EnvironmentObject var state: AppState
    @AppStorage("method") private var method: String = "bad_query"
    @State private var is_valid: Bool = false
    @State private var show_settings: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LogView()
                        .modifier(TerminalPlatter())
                } header: {
                    Label("Logs", systemImage: "apple.terminal")
                }

                Section {
                    NavigationLink {
                        GestaltView()
                    } label: {
                        Text("MobileGestalt")
                    }

                    NavigationLink {
                        PosterView()
                    } label: {
                        Text("PosterBoard")
                    }
                    .disabled(method == "cmg" || !state.exploit_succeeded)

                    NavigationLink {
                        SantanderView()
                    } label: {
                        Text("HouseArrest")
                    }
                    .disabled(true)
                } header: {
                    Label("Tweaks", systemImage: "paintbrush")
                } footer: {
                    if method == "cmg" {
                        Text("Only MobileGestalt is available when method is set to cmg.\nHouseArrest is still in development and may not work as expected.")
                    } else if !state.exploit_succeeded {
                        Text("PosterBoard requires the exploit to succeed. Check logs for errors.")
                    } else {
                        Text("HouseArrest is still in development and may not work as expected.")
                    }
                }

                Section {
                    HStack {
                        Text("Exploit Status")
                        Spacer()
                        if state.exploit_succeeded {
                            Label("Active", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Label("Inactive", systemImage: "xmark.circle.fill")
                                .foregroundStyle(.red)
                        }
                    }

                    HStack {
                        Text("Method")
                        Spacer()
                        Text(method)
                            .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text("iOS")
                        Spacer()
                        Text(UIDevice.current.systemVersion)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("Status", systemImage: "info.circle")
                }
            }
            .navigationTitle("mond")
            .tint(Color("AccentColor"))
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack {
                        Button {
                            show_settings = true
                        } label: {
                            Image(systemName: "gear")
                        }
                    }
                }
            }
            .sheet(isPresented: $show_settings) {
                SettingsView()
            }
        }
    }
}