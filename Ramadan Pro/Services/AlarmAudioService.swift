//
//  AlarmAudioService.swift
//  Ramadan Pro
//

import Foundation
import AVFoundation

@MainActor
final class AlarmAudioService: NSObject {
    static let shared = AlarmAudioService()

    private var player: AVAudioPlayer?
    private var previewTask: Task<Void, Never>?

    private override init() {
        super.init()
    }

    func startAlarmLoop(soundName: String, volume: Float) {
        previewTask?.cancel()
        configureSession()

        guard let option = AlarmSoundOption(rawValue: soundName) else {
            print("⚠️ AlarmAudioService: Invalid audio option \(soundName)")
            return
        }
        
        let url = audioURL(for: option)
        guard let url = url, FileManager.default.fileExists(atPath: url.path) else {
            print("⚠️ AlarmAudioService: Missing audio file for \(soundName)")
            return
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = -1
            player?.volume = max(0, min(volume, 1))
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("⚠️ AlarmAudioService: Failed to start alarm audio - \(error.localizedDescription)")
        }
    }

    func playPreview(soundName: String, volume: Float = 1.0) {
        stop()
        configureSession()
        
        guard let option = AlarmSoundOption(rawValue: soundName),
              let url = audioURL(for: option),
              FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.numberOfLoops = 0
            player?.volume = max(0, min(volume, 1))
            player?.prepareToPlay()
            player?.play()
        } catch {
            print("⚠️ AlarmAudioService: Failed to play preview - \(error.localizedDescription)")
        }
    }

    func stop() {
        previewTask?.cancel()
        previewTask = nil
        player?.stop()
        player = nil
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("⚠️ AlarmAudioService: Failed to deactivate audio session - \(error.localizedDescription)")
        }
    }

    private func configureSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("⚠️ AlarmAudioService: Failed to configure audio session - \(error.localizedDescription)")
        }
    }

    private func audioURL(for option: AlarmSoundOption) -> URL? {
        if option == .custom {
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            return docDir.appendingPathComponent("custom_alarm_audio.m4a")
        }
        return Bundle.main.url(forResource: option.assetFileName, withExtension: "mp3")
    }

    func saveCustomAudio(from url: URL) throws {
        let isSecured = url.startAccessingSecurityScopedResource()
        defer {
            if isSecured {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destURL = docDir.appendingPathComponent("custom_alarm_audio.m4a")
        
        if FileManager.default.fileExists(atPath: destURL.path) {
            try FileManager.default.removeItem(at: destURL)
        }
        
        try FileManager.default.copyItem(at: url, to: destURL)
    }
}
