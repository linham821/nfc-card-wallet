import SwiftUI
import AVFoundation

/// QR/条码扫描视图：用 AVFoundation 实时识别。
/// 支持 QR、Code128、Code39、EAN13 等常见码制。
struct QRScannerView: UIViewControllerRepresentable {

    /// 扫描结果回调
    var onScan: (String) -> Void

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let vc = QRScannerViewController()
        vc.onScan = onScan
        return vc
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {}
}

final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var onScan: ((String) -> Void)?
    private let session = AVCaptureSession()
    private let previewLayer = AVCaptureVideoPreviewLayer()
    private var scanBoxView: UIView?
    private var hasReported = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupSession()
        setupOverlay()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer.frame = view.bounds
        if let connection = previewLayer.connection {
            connection.videoOrientation = orientationFromUI()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasReported = false
        if !session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if session.isRunning {
            session.stopRunning()
        }
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video) else {
            showError("无可用摄像头")
            return
        }
        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) { session.addInput(input) }
        } catch {
            showError("摄像头初始化失败：\(error.localizedDescription)")
            return
        }

        let output = AVCaptureMetadataOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
            output.metadataObjectTypes = [
                .qr, .code128, .code39, .code93, .ean13, .ean8, .upce, .dataMatrix
            ]
            output.setMetadataObjectsDelegate(self, queue: .main)
        }

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
    }

    private func setupOverlay() {
        // 半透明遮罩 + 中央扫描框
        let overlay = CAShapeLayer()
        overlay.backgroundColor = UIColor.black.withAlphaComponent(0.55).cgColor
        view.layer.addSublayer(overlay)

        let boxSize = CGSize(width: 240, height: 240)
        let boxFrame = CGRect(
            x: (view.bounds.width - boxSize.width) / 2,
            y: (view.bounds.height - boxSize.height) / 2,
            width: boxSize.width,
            height: boxSize.height
        )
        let path = UIBezierPath(roundedRect: view.bounds, cornerRadius: 0)
        path.append(UIBezierPath(roundedRect: boxFrame, cornerRadius: 16).reversing())
        overlay.path = path.cgPath
        overlay.fillRule = .evenOdd

        // 扫描框边
        let boxView = UIView(frame: boxFrame)
        boxView.layer.borderColor = UIColor.systemBlue.cgColor
        boxView.layer.borderWidth = 2
        boxView.layer.cornerRadius = 16
        view.addSubview(boxView)
        scanBoxView = boxView

        // 提示文字
        let label = UILabel()
        label.text = "把卡上的二维码/条码对准框内"
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.sizeToFit()
        label.frame = CGRect(
            x: (view.bounds.width - label.bounds.width) / 2,
            y: boxFrame.maxY + 24,
            width: label.bounds.width,
            height: label.bounds.height
        )
        view.addSubview(label)

        // 关闭按钮
        let closeBtn = UIButton(type: .system)
        closeBtn.setTitle("关闭", for: .normal)
        closeBtn.setTitleColor(.white, for: .normal)
        closeBtn.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        closeBtn.sizeToFit()
        closeBtn.frame = CGRect(x: 16, y: 16, width: closeBtn.bounds.width, height: 44)
        closeBtn.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        view.addSubview(closeBtn)
    }

    @objc private func closeTapped() {
        dismiss(animated: true)
    }

    private func orientationFromUI() -> AVCaptureVideoOrientation {
        switch UIDevice.current.orientation {
        case .portrait: return .portrait
        case .landscapeLeft: return .landscapeRight
        case .landscapeRight: return .landscapeLeft
        case .portraitUpsideDown: return .portraitUpsideDown
        default: return .portrait
        }
    }

    private func showError(_ message: String) {
        let label = UILabel()
        label.text = message
        label.textColor = .white
        label.numberOfLines = 0
        label.textAlignment = .center
        label.font = .systemFont(ofSize: 16)
        label.frame = view.bounds.insetBy(dx: 32, dy: 0)
        view.addSubview(label)
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasReported,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let value = obj.stringValue else { return }
        hasReported = true
        // 触觉反馈
        DispatchQueue.main.async {
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.impactOccurred()
        }
        // 停止扫描并回调
        session.stopRunning()
        onScan?(value)
        dismiss(animated: true)
    }
}
