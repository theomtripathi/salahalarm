//
//  SAAlarmUI.swift
//  Ramadan Pro
//

import SwiftUI
import UniformTypeIdentifiers
import Combine
import UIKit
import AVFoundation

struct SAAlarmPulseView: View {
    @State private var animate = false

    var color: Color = .white

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .stroke(color.opacity(0.35 - Double(index) * 0.08), lineWidth: 2)
                    .frame(width: 120 + CGFloat(index * 48), height: 120 + CGFloat(index * 48))
                    .scaleEffect(animate ? 1.08 : 0.88)
                    .opacity(animate ? 0.15 : 0.65)
                    .animation(
                        .easeOut(duration: 1.8)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animate
                    )
            }

            Image(systemName: "bell.fill")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(color)
        }
        .onAppear {
            animate = true
        }
    }
}

struct SAAlarmSilentWarningBanner: View {
    @ObservedObject var alarmViewModel: AlarmViewModel

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppColors.slGold)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("alarm sound requires action")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(AppColors.slTextPrimary)
                Text("turn off Silent Mode and Do Not Disturb so your alarms ring.")
                    .font(.system(size: 12))
                    .foregroundColor(AppColors.slTextSecondary)
                Button("fix ->") {
                    alarmViewModel.showSoundSetupSheet = true
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(AppColors.slGold)
            }

            Spacer()

            Button {
                alarmViewModel.dismissSilentWarning()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(AppColors.slTextSecondary)
            }
        }
        .padding(14)
        .background(Color(hex: "#FFF8E7"))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(AppColors.slGold, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct SAAlarmSoundSetupSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Before alarms can work reliably, double-check these settings.")
                    .font(.system(size: 16))
                    .foregroundColor(AppColors.slTextSecondary)

                soundRow(icon: "bell.slash.fill", title: "Silent mode", detail: "Keep the phone out of silent mode during prayer windows.")
                soundRow(icon: "moon.zzz.fill", title: "Do Not Disturb", detail: "Allow SalahAlarm notifications to break through Focus modes.")
                soundRow(icon: "speaker.wave.3.fill", title: "Volume", detail: "Set your ringer and media volume high enough for Fajr.")

                Spacer()

                SLPrimaryButton(title: "done") {
                    dismiss()
                }
            }
            .padding(24)
            .navigationTitle("Alarm Setup")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func soundRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .foregroundColor(AppColors.slGreen)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.text(title))
                    .font(.system(size: 16, weight: .semibold))
                Text(L10n.text(detail))
                    .font(.system(size: 14))
                    .foregroundColor(AppColors.slTextSecondary)
            }
        }
    }
}

struct SAAlarmSettingsSheet: View {
    @ObservedObject var alarmViewModel: AlarmViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showFileImporter = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Prayer alarms") {
                    Toggle("Enable all alarms", isOn: Binding(
                        get: { alarmViewModel.settings.alarmsEnabled },
                        set: { alarmViewModel.setAlarmsEnabled($0) }
                    ))

                    ForEach(PrayerName.allCases) { prayer in
                        Toggle(L10n.text(prayer.displayName), isOn: Binding(
                            get: { alarmViewModel.settings.isEnabled(for: prayer) },
                            set: { alarmViewModel.setPrayerEnabled($0, for: prayer) }
                        ))
                    }
                }

                Section("Strictness") {
                    Picker("Mode", selection: Binding(
                        get: { alarmViewModel.settings.strictness },
                        set: { alarmViewModel.setStrictness($0) }
                    )) {
                        ForEach(AlarmStrictness.allCases, id: \.self) { strictness in
                            Text(L10n.text(strictness.displayLabel)).tag(strictness)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text(L10n.text(alarmViewModel.settings.strictness.detailText))
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.slTextSecondary)
                }

                Section("Sound") {
                    Picker("Alarm sound", selection: Binding(
                        get: { alarmViewModel.settings.soundName },
                        set: { alarmViewModel.setSound($0) }
                    )) {
                        ForEach(AlarmSoundOption.allCases, id: \.rawValue) { sound in
                            if sound == .custom {
                                Button(L10n.text(sound.displayName)) {
                                    showFileImporter = true
                                }.tag(sound.rawValue)
                            } else {
                                Text(L10n.text(sound.displayName)).tag(sound.rawValue)
                            }
                        }
                    }

                    Button("Test alarm overlay") {
                        dismiss()
                        alarmViewModel.triggerTestAlarm()
                    }
                    .foregroundColor(AppColors.saAlarmRed)
                }

                if !alarmViewModel.logs.isEmpty {
                    Section("Recent alarm activity") {
                        ForEach(alarmViewModel.logs.prefix(5)) { log in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(log.prayer.displayName) • \(log.scheduledTime.timeString())")
                                    .font(.system(size: 15, weight: .semibold))
                                Text(log.dismissalMethod.rawValue.capitalized)
                                    .font(.system(size: 13))
                                    .foregroundColor(AppColors.slTextSecondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Alarm Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        AlarmAudioService.shared.stop()
                        dismiss()
                    }
                }
            }
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.audio]) { result in
            switch result {
            case .success(let url):
                do {
                    try AlarmAudioService.shared.saveCustomAudio(from: url)
                    alarmViewModel.setSound(AlarmSoundOption.custom.rawValue)
                    AlarmAudioService.shared.playPreview(soundName: AlarmSoundOption.custom.rawValue)
                } catch {
                    print("Failed to save custom audio: \(error)")
                }
            case .failure(let error):
                print("Failed to import custom audio: \(error)")
            }
        }
    }
}

struct SAMatScanView: View {
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    @State private var cameraUnavailable = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Group {
                    if let capturedImage {
                        Image(uiImage: capturedImage)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 24))
                    } else {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(AppColors.slGreen, style: StrokeStyle(lineWidth: 2, dash: [10]))
                            .frame(height: 320)
                            .overlay {
                                VStack(spacing: 16) {
                                    Image(systemName: "camera.viewfinder")
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(AppColors.slGreen)
                                    Text("Point your camera at your prayer mat.")
                                        .font(.system(size: 18, weight: .semibold))
                                    Text("Capture a photo of your janamaz to dismiss this alarm.")
                                        .font(.system(size: 14))
                                        .foregroundColor(AppColors.slTextSecondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(24)
                            }
                    }
                }

                SLPrimaryButton(title: capturedImage == nil ? "open camera" : "confirm mat scan") {
                    if capturedImage == nil {
                        openCamera()
                    } else {
                        onConfirm()
                        dismiss()
                    }
                }

                if capturedImage != nil {
                    SLSecondaryButton(title: "retake photo") {
                        openCamera()
                    }
                }
            }
            .padding(24)
            .navigationTitle("Mat Scan")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showCamera) {
                SACameraPicker(image: $capturedImage)
            }
            .alert("Camera unavailable", isPresented: $cameraUnavailable) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("This simulator does not provide a camera feed. Test mat scan on a device.")
            }
        }
    }

    private func openCamera() {
        if UIImagePickerController.isSourceTypeAvailable(.camera) {
            showCamera = true
        } else {
            cameraUnavailable = true
        }
    }
}

struct SACameraPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator {
        Coordinator(image: $image, dismiss: dismiss)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        @Binding private var image: UIImage?
        private let dismiss: DismissAction

        init(image: Binding<UIImage?>, dismiss: DismissAction) {
            _image = image
            self.dismiss = dismiss
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            image = info[.originalImage] as? UIImage
            dismiss()
        }
    }
}

struct SAActiveAlarmOverlay: View {
    @ObservedObject var alarmViewModel: AlarmViewModel
    let alarm: AlarmViewModel.ActiveAlarmPresentation

    @State private var now = Date()
    @State private var showMatScan = false
    @State private var showManualConfirmation = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.saAlarmRed, Color(hex: "#B71C1C")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text(L10n.text(alarm.prayer.displayName))
                        .font(.system(size: 42, weight: .bold))
                        .foregroundColor(.white)
                    Text(alarm.prayer.arabicName)
                        .font(.system(size: 26))
                        .foregroundColor(.white.opacity(0.92))
                    Text(now.timeString())
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white.opacity(0.82))
                }
                .padding(.top, 40)

                SAAlarmPulseView()

                VStack(alignment: .leading, spacing: 18) {
                    Text("scan your prayer mat to dismiss")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text("Point your camera at your janamaz and confirm the scan.")
                        .font(.system(size: 14))
                        .foregroundColor(AppColors.slTextSecondary)

                    SLPrimaryButton(title: "scan mat") {
                        showMatScan = true
                    }


                    if alarmViewModel.settings.strictness != .strict {
                        Button("dismiss manually") {
                            showManualConfirmation = true
                        }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(AppColors.slTextSecondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .padding(.horizontal, 20)

                Spacer()
            }
        }
        .onReceive(timer) { value in
            now = value
        }
        .sheet(isPresented: $showMatScan) {
            SAMatScanView {
                alarmViewModel.dismissWithMatScan()
            }
        }
        .alert("Dismiss without praying?", isPresented: $showManualConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Yes, I'll pray later", role: .destructive) {
                alarmViewModel.dismissManually()
            }
        } message: {
            Text("Use manual dismissal only if you need to come back later.")
        }
    }
}
