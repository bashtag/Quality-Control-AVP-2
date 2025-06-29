//
//  SpeechRecognizer.swift
//  ObjectPlacement
//
//  Created by Melike SEYİTOĞLU on 21.06.2025.
//  Copyright © 2025 Apple. All rights reserved.
//

 
import Speech
import AVFoundation
 
class SpeechRecognizer: ObservableObject {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @Published var transcribedText: String = ""
 
    func startRecognition() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            guard authStatus == .authorized else {
                print("Speech recognition not authorized")
                return
            }
 
            DispatchQueue.main.async {
                self.startRecording()
            }
        }
    }
 
    func stopRecognition() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }
 
    private func startRecording() {
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        let inputNode = audioEngine.inputNode
        guard let recognitionRequest = recognitionRequest else { return }
 
        recognitionRequest.shouldReportPartialResults = true
 
        recognitionTask = recognizer?.recognitionTask(with: recognitionRequest) { result, error in
            if let result = result {
                DispatchQueue.main.async {
                    self.transcribedText = result.bestTranscription.formattedString
                }
            }
        }
 
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }
 
        audioEngine.prepare()
        try? audioEngine.start()
    }
}
