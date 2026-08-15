//
//  DiagnosticsView.swift
//  mond
//
//  Диагностика и проверка совместимости твиков
//

import SwiftUI
import PartyUI

struct DiagnosticsView: View {
    @State private var report = ""
    @State private var compatibilityResults: [String: TweakStatus] = [:]
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Device Information")
                        .font(.headline)
                    LabeledContent("Device", value: machine_name())
                    LabeledContent("iOS Version", value: UIDevice.current.systemVersion)
                }
                
                Section("Tweak Compatibility") {
                    ForEach(Array(compatibilityResults.keys.sorted()), id: \.self) { tweak in
                        HStack {
                            Text(tweak)
                            Spacer()
                            switch compatibilityResults[tweak] {
                            case .working:
                                Label("Working", systemImage: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            case .requiresSpoof:
                                Label("Needs Spoof", systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                            case .incompatible:
                                Label("Incompatible", systemImage: "xmark.circle.fill")
                                    .foregroundStyle(.red)
                            case .unknown:
                                Label("Unknown", systemImage: "questionmark.circle")
                                    .foregroundStyle(.gray)
                            case .none:
                                EmptyView()
                            }
                        }
                    }
                }
                
                Section {
                    Button("Generate Full Report") {
                        report = Diagnostics.generateReport()
                    }
                    
                    Button("Copy Report") {
                        UIPasteboard.general.string = report
                        Alertinator.shared.alert(title: "Copied!", body: "Report copied to clipboard")
                    }
                    .disabled(report.isEmpty)
                }
                
                if !report.isEmpty {
                    Section("Report") {
                        Text(report)
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Diagnostics")
            .onAppear {
                compatibilityResults = Diagnostics.checkTweakCompatibility()
            }
        }
    }
}