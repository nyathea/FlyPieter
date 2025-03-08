import UIKit
import WebKit
import CoreMotion

class ViewController: UIViewController, WKScriptMessageHandler {
    
    private var webView: WKWebView!
    private let motionManager = CMMotionManager()
    private var overlayLabel: UILabel!
    private var resetButton: UIButton!
    private var baseAmpPlusButton: UIButton!
    private var baseAmpMinusButton: UIButton!
    private var decayPlusButton: UIButton!
    private var decayMinusButton: UIButton!
    private var pitchBaseAmpPlusButton: UIButton!
    private var pitchBaseAmpMinusButton: UIButton!
    private var pitchDecayPlusButton: UIButton!
    private var pitchDecayMinusButton: UIButton!
    private var rollBaseline: Double?
    
    // Add haptic feedback generator
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .heavy)
    
    
    private var baseAmplification: Double = 4.9
    private var decayFactor: Double = 2.7
    private var pitchBaseAmplification: Double = 4.9
    private var pitchDecayFactor: Double = 2.7
    
    private let debug = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupOverlayLabel()
        setupResetButton()
        setupCalibrationButtons()
        loadWebContent()
        calibrateMotion()
        
        // Prepare haptic feedback
        hapticFeedback.prepare()
    }
    
    // MARK: - WebView Setup
    private func setupWebView() {
        let configuration = WKWebViewConfiguration()
        configuration.mediaTypesRequiringUserActionForPlayback = .all
        configuration.allowsInlineMediaPlayback = true
        
        // Add script message handler
        configuration.userContentController.add(self, name: "missileFired")
        
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.translatesAutoresizingMaskIntoConstraints = false
        
        view.addSubview(webView)
        
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            webView.widthAnchor.constraint(equalToConstant: view.bounds.width)
        ])
        
        webView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: 22).isActive = true
        webView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: -60).isActive = true
        webView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: 60).isActive = true
        
        // Inject JavaScript after web content loads
        webView.configuration.userContentController.addUserScript(
            WKUserScript(
                source: """
                    (function() {
                        const originalShootMissile = window.shootMissile;
                        window.shootMissile = function() {
                            originalShootMissile.apply(this, arguments); // Call original function
                            if (webkit && webkit.messageHandlers && webkit.messageHandlers.missileFired) {
                                webkit.messageHandlers.missileFired.postMessage('Missile fired');
                            }
                        };
                
                        // Inject CSS
                        const style = document.createElement('style');
                        style.textContent = '.vehicle-option { height: 24px !important; }';
                        document.head.appendChild(style);
                    })();
                """,
                injectionTime: .atDocumentEnd,
                forMainFrameOnly: true
            )
        )
    }
    
    private func loadWebContent() {
        guard let url = URL(string: "https://fly.pieter.com") else { return }
        webView.load(URLRequest(url: url))
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "missileFired" {
                print("Missile fired detected!")
                
                // Trigger haptic feedback
                hapticFeedback.impactOccurred()
                
                // Prepare for next feedback
                hapticFeedback.prepare()
                
                if debug {
                    overlayLabel.text = """
                        Roll Base Amp: \(String(format: "%.2f", baseAmplification))
                        Roll Decay: \(String(format: "%.2f", decayFactor))
                        Pitch Base Amp: \(String(format: "%.2f", pitchBaseAmplification))
                        Pitch Decay: \(String(format: "%.2f", pitchDecayFactor))
                        Missile Fired!
                    """
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        self?.updateOverlay() // Reset overlay after brief display
                    }
                }
            }
        }
    
    // Helper to update overlay with motion data only
    private func updateOverlay(roll: Double = 0.0, pitch: Double = 0.0) {
        let overlayText = """
            Roll Base Amp: \(String(format: "%.2f", baseAmplification))
            Roll Decay: \(String(format: "%.2f", decayFactor))
            Pitch Base Amp: \(String(format: "%.2f", pitchBaseAmplification))
            Pitch Decay: \(String(format: "%.2f", pitchDecayFactor))
            -Clamped Roll: \(String(format: "%.2f", roll))
            Clamped Pitch: \(String(format: "%.2f", pitch))
        """
        overlayLabel.text = overlayText
    }
    
    // MARK: - Overlay Setup
    private func setupOverlayLabel() {
        overlayLabel = UILabel()
        overlayLabel.translatesAutoresizingMaskIntoConstraints = false
        overlayLabel.numberOfLines = 0
        overlayLabel.font = .systemFont(ofSize: 12)
        overlayLabel.textColor = .yellow
        overlayLabel.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        overlayLabel.isHidden = !debug
        
        view.addSubview(overlayLabel)
        
        NSLayoutConstraint.activate([
            overlayLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            overlayLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 8),
            overlayLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -8)
        ])
    }
    
    // MARK: - Reset Button Setup
    private func setupResetButton() {
        resetButton = UIButton(type: .system)
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        resetButton.setTitle("Reset", for: .normal)
        resetButton.titleLabel?.font = .systemFont(ofSize: 14)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        resetButton.layer.cornerRadius = 8
        resetButton.addTarget(self, action: #selector(resetRollBaseline), for: .touchUpInside)
        resetButton.isHidden = !debug
        
        view.addSubview(resetButton)
        
        NSLayoutConstraint.activate([
            resetButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 8),
            resetButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            resetButton.widthAnchor.constraint(equalToConstant: 60),
            resetButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    // MARK: - Calibration Buttons Setup
    private func setupCalibrationButtons() {
        // Base Amplification + Button (Roll)
        baseAmpPlusButton = UIButton(type: .system)
        baseAmpPlusButton.translatesAutoresizingMaskIntoConstraints = false
        baseAmpPlusButton.setTitle("+", for: .normal)
        baseAmpPlusButton.titleLabel?.font = .systemFont(ofSize: 14)
        baseAmpPlusButton.setTitleColor(.white, for: .normal)
        baseAmpPlusButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        baseAmpPlusButton.layer.cornerRadius = 8
        baseAmpPlusButton.addTarget(self, action: #selector(increaseBaseAmplification), for: .touchUpInside)
        baseAmpPlusButton.isHidden = !debug
        
        // Base Amplification - Button (Roll)
        baseAmpMinusButton = UIButton(type: .system)
        baseAmpMinusButton.translatesAutoresizingMaskIntoConstraints = false
        baseAmpMinusButton.setTitle("-", for: .normal)
        baseAmpMinusButton.titleLabel?.font = .systemFont(ofSize: 14)
        baseAmpMinusButton.setTitleColor(.white, for: .normal)
        baseAmpMinusButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        baseAmpMinusButton.layer.cornerRadius = 8
        baseAmpMinusButton.addTarget(self, action: #selector(decreaseBaseAmplification), for: .touchUpInside)
        baseAmpMinusButton.isHidden = !debug
        
        // Decay Factor + Button (Roll)
        decayPlusButton = UIButton(type: .system)
        decayPlusButton.translatesAutoresizingMaskIntoConstraints = false
        decayPlusButton.setTitle("+", for: .normal)
        decayPlusButton.titleLabel?.font = .systemFont(ofSize: 14)
        decayPlusButton.setTitleColor(.white, for: .normal)
        decayPlusButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        decayPlusButton.layer.cornerRadius = 8
        decayPlusButton.addTarget(self, action: #selector(increaseDecayFactor), for: .touchUpInside)
        decayPlusButton.isHidden = !debug
        
        // Decay Factor - Button (Roll)
        decayMinusButton = UIButton(type: .system)
        decayMinusButton.translatesAutoresizingMaskIntoConstraints = false
        decayMinusButton.setTitle("-", for: .normal)
        decayMinusButton.titleLabel?.font = .systemFont(ofSize: 14)
        decayMinusButton.setTitleColor(.white, for: .normal)
        decayMinusButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        decayMinusButton.layer.cornerRadius = 8
        decayMinusButton.addTarget(self, action: #selector(decreaseDecayFactor), for: .touchUpInside)
        decayMinusButton.isHidden = !debug
        
        // Pitch Base Amplification + Button
        pitchBaseAmpPlusButton = UIButton(type: .system)
        pitchBaseAmpPlusButton.translatesAutoresizingMaskIntoConstraints = false
        pitchBaseAmpPlusButton.setTitle("+", for: .normal)
        pitchBaseAmpPlusButton.titleLabel?.font = .systemFont(ofSize: 14)
        pitchBaseAmpPlusButton.setTitleColor(.white, for: .normal)
        pitchBaseAmpPlusButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        pitchBaseAmpPlusButton.layer.cornerRadius = 8
        pitchBaseAmpPlusButton.addTarget(self, action: #selector(increasePitchBaseAmplification), for: .touchUpInside)
        pitchBaseAmpPlusButton.isHidden = !debug
        
        // Pitch Base Amplification - Button
        pitchBaseAmpMinusButton = UIButton(type: .system)
        pitchBaseAmpMinusButton.translatesAutoresizingMaskIntoConstraints = false
        pitchBaseAmpMinusButton.setTitle("-", for: .normal)
        pitchBaseAmpMinusButton.titleLabel?.font = .systemFont(ofSize: 14)
        pitchBaseAmpMinusButton.setTitleColor(.white, for: .normal)
        pitchBaseAmpMinusButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        pitchBaseAmpMinusButton.layer.cornerRadius = 8
        pitchBaseAmpMinusButton.addTarget(self, action: #selector(decreasePitchBaseAmplification), for: .touchUpInside)
        pitchBaseAmpMinusButton.isHidden = !debug
        
        // Pitch Decay Factor + Button
        pitchDecayPlusButton = UIButton(type: .system)
        pitchDecayPlusButton.translatesAutoresizingMaskIntoConstraints = false
        pitchDecayPlusButton.setTitle("+", for: .normal)
        pitchDecayPlusButton.titleLabel?.font = .systemFont(ofSize: 14)
        pitchDecayPlusButton.setTitleColor(.white, for: .normal)
        pitchDecayPlusButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        pitchDecayPlusButton.layer.cornerRadius = 8
        pitchDecayPlusButton.addTarget(self, action: #selector(increasePitchDecayFactor), for: .touchUpInside)
        pitchDecayPlusButton.isHidden = !debug
        
        // Pitch Decay Factor - Button
        pitchDecayMinusButton = UIButton(type: .system)
        pitchDecayMinusButton.translatesAutoresizingMaskIntoConstraints = false
        pitchDecayMinusButton.setTitle("-", for: .normal)
        pitchDecayMinusButton.titleLabel?.font = .systemFont(ofSize: 14)
        pitchDecayMinusButton.setTitleColor(.white, for: .normal)
        pitchDecayMinusButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        pitchDecayMinusButton.layer.cornerRadius = 8
        pitchDecayMinusButton.addTarget(self, action: #selector(decreasePitchDecayFactor), for: .touchUpInside)
        pitchDecayMinusButton.isHidden = !debug
        
        view.addSubview(baseAmpPlusButton)
        view.addSubview(baseAmpMinusButton)
        view.addSubview(decayPlusButton)
        view.addSubview(decayMinusButton)
        view.addSubview(pitchBaseAmpPlusButton)
        view.addSubview(pitchBaseAmpMinusButton)
        view.addSubview(pitchDecayPlusButton)
        view.addSubview(pitchDecayMinusButton)
        
        NSLayoutConstraint.activate([
            baseAmpPlusButton.leadingAnchor.constraint(equalTo: resetButton.trailingAnchor, constant: 8),
            baseAmpPlusButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            baseAmpPlusButton.widthAnchor.constraint(equalToConstant: 30),
            baseAmpPlusButton.heightAnchor.constraint(equalToConstant: 30),
            
            baseAmpMinusButton.leadingAnchor.constraint(equalTo: baseAmpPlusButton.trailingAnchor, constant: 8),
            baseAmpMinusButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            baseAmpMinusButton.widthAnchor.constraint(equalToConstant: 30),
            baseAmpMinusButton.heightAnchor.constraint(equalToConstant: 30),
            
            decayPlusButton.leadingAnchor.constraint(equalTo: baseAmpMinusButton.trailingAnchor, constant: 8),
            decayPlusButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            decayPlusButton.widthAnchor.constraint(equalToConstant: 30),
            decayPlusButton.heightAnchor.constraint(equalToConstant: 30),
            
            decayMinusButton.leadingAnchor.constraint(equalTo: decayPlusButton.trailingAnchor, constant: 8),
            decayMinusButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            decayMinusButton.widthAnchor.constraint(equalToConstant: 30),
            decayMinusButton.heightAnchor.constraint(equalToConstant: 30),
            
            pitchBaseAmpPlusButton.leadingAnchor.constraint(equalTo: decayMinusButton.trailingAnchor, constant: 8),
            pitchBaseAmpPlusButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            pitchBaseAmpPlusButton.widthAnchor.constraint(equalToConstant: 30),
            pitchBaseAmpPlusButton.heightAnchor.constraint(equalToConstant: 30),
            
            pitchBaseAmpMinusButton.leadingAnchor.constraint(equalTo: pitchBaseAmpPlusButton.trailingAnchor, constant: 8),
            pitchBaseAmpMinusButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            pitchBaseAmpMinusButton.widthAnchor.constraint(equalToConstant: 30),
            pitchBaseAmpMinusButton.heightAnchor.constraint(equalToConstant: 30),
            
            pitchDecayPlusButton.leadingAnchor.constraint(equalTo: pitchBaseAmpMinusButton.trailingAnchor, constant: 8),
            pitchDecayPlusButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            pitchDecayPlusButton.widthAnchor.constraint(equalToConstant: 30),
            pitchDecayPlusButton.heightAnchor.constraint(equalToConstant: 30),
            
            pitchDecayMinusButton.leadingAnchor.constraint(equalTo: pitchDecayPlusButton.trailingAnchor, constant: 8),
            pitchDecayMinusButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8),
            pitchDecayMinusButton.widthAnchor.constraint(equalToConstant: 30),
            pitchDecayMinusButton.heightAnchor.constraint(equalToConstant: 30)
        ])
    }
    
    // MARK: - Calibration Button Actions
    @objc private func increaseBaseAmplification() {
        baseAmplification += 0.1
        print("Roll Base Amplification increased to: \(baseAmplification)")
    }
    
    @objc private func decreaseBaseAmplification() {
        baseAmplification = max(0.1, baseAmplification - 0.1)
        print("Roll Base Amplification decreased to: \(baseAmplification)")
    }
    
    @objc private func increaseDecayFactor() {
        decayFactor += 0.1
        print("Roll Decay Factor increased to: \(decayFactor)")
    }
    
    @objc private func decreaseDecayFactor() {
        decayFactor = max(0.1, decayFactor - 0.1)
        print("Roll Decay Factor decreased to: \(decayFactor)")
    }
    
    @objc private func increasePitchBaseAmplification() {
        pitchBaseAmplification += 0.1
        print("Pitch Base Amplification increased to: \(pitchBaseAmplification)")
    }
    
    @objc private func decreasePitchBaseAmplification() {
        pitchBaseAmplification = max(0.1, pitchBaseAmplification - 0.1)
        print("Pitch Base Amplification decreased to: \(pitchBaseAmplification)")
    }
    
    @objc private func increasePitchDecayFactor() {
        pitchDecayFactor += 0.1
        print("Pitch Decay Factor increased to: \(pitchDecayFactor)")
    }
    
    @objc private func decreasePitchDecayFactor() {
        pitchDecayFactor = max(0.1, pitchDecayFactor - 0.1)
        print("Pitch Decay Factor decreased to: \(pitchDecayFactor)")
    }
    
    // MARK: - Calibration
    private func calibrateMotion() {
        guard motionManager.isDeviceMotionAvailable else { return }
        
        motionManager.stopDeviceMotionUpdates()
        motionManager.deviceMotionUpdateInterval = 0.02
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            self.rollBaseline = motion.attitude.roll
            self.motionManager.stopDeviceMotionUpdates()
            self.setupMotionTracking()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.rollBaseline == nil {
                self.rollBaseline = 0.0
                self.motionManager.stopDeviceMotionUpdates()
                self.setupMotionTracking()
            }
        }
    }
    
    // MARK: - Reset Action
    @objc private func resetRollBaseline() {
        calibrateMotion()
    }
    
    // MARK: - Motion Tracking
    private func setupMotionTracking() {
        guard motionManager.isDeviceMotionAvailable, rollBaseline != nil else { return }
        
        motionManager.deviceMotionUpdateInterval = 0.02
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let self = self, let motion = motion else { return }
            
            let roll = motion.attitude.roll
            let pitch = motion.attitude.pitch
            
            let rawRotation = roll - self.rollBaseline!
            let rollMultiplier = self.baseAmplification * exp(-self.decayFactor * abs(rawRotation))
            let planeRotation = rawRotation * rollMultiplier
            let clampedPlaneRotation = max(min(planeRotation, 1.0), -1.0)
            
            let rawPitch = -pitch
            let pitchMultiplier = self.pitchBaseAmplification * exp(-self.pitchDecayFactor * abs(rawPitch))
            let planeTilt = rawPitch * pitchMultiplier
            let clampedPlaneTilt = max(min(planeTilt, 1.0), -1.0)

            self.updateOverlay(roll: -clampedPlaneRotation, pitch: clampedPlaneTilt)
            
            let jsCode = """
                if (typeof leftJoystickData !== 'undefined') {
                    leftJoystickData.x = \(clampedPlaneTilt);
                    leftJoystickData.y = \(-clampedPlaneRotation);
                }
            """

            self.webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("JavaScript injection error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Cleanup

    deinit {
        motionManager.stopDeviceMotionUpdates()
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "missileFired")
        // No need to cleanup hapticFeedback as it's automatically managed
    }
}
