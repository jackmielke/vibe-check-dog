import XCTest
import UIKit
@testable import Vibe_Check

/// The camera -> API hop is the one link the simulator cannot exercise, so pin
/// down the encoding step that sits in the middle of it.
final class ImageEncodingTests: XCTestCase {

    /// A scale-1 image, so "points" and "pixels" are the same number and the
    /// assertions below are unambiguous.
    private func image(_ w: CGFloat, _ h: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: w, height: h), format: format).image { ctx in
            UIColor.systemTeal.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: w, height: h))
        }
    }

    func testProducesADecodableJPEGDataURL() throws {
        let url = image(400, 300).vibeDataURL()
        XCTAssertTrue(url.hasPrefix("data:image/jpeg;base64,"))
        let b64 = String(url.dropFirst("data:image/jpeg;base64,".count))
        let data = try XCTUnwrap(Data(base64Encoded: b64), "payload must be valid base64")
        XCTAssertNotNil(UIImage(data: data), "payload must decode back to an image")
        // JPEG magic number.
        XCTAssertEqual(Array(data.prefix(2)), [0xFF, 0xD8])
    }

    func testLargeImagesAreDownscaled() throws {
        let url = image(4000, 3000).vibeDataURL(maxEdge: 1024)
        let b64 = String(url.dropFirst("data:image/jpeg;base64,".count))
        let data = try XCTUnwrap(Data(base64Encoded: b64))
        let decoded = try XCTUnwrap(UIImage(data: data))
        XCTAssertLessThanOrEqual(max(decoded.size.width, decoded.size.height), 1024.5,
                                 "a 4000px selfie must be shrunk before upload")
        XCTAssertLessThan(data.count, 900_000, "payload should stay small enough to post quickly")
    }

    func testSmallImagesAreNotUpscaled() throws {
        let url = image(200, 200).vibeDataURL(maxEdge: 1024)
        let b64 = String(url.dropFirst("data:image/jpeg;base64,".count))
        let decoded = try XCTUnwrap(UIImage(data: try XCTUnwrap(Data(base64Encoded: b64))))
        XCTAssertEqual(decoded.size.width, 200, accuracy: 1)
    }

    func testOrientationIsBakedIn() throws {
        let base = try XCTUnwrap(image(100, 50).cgImage)   // 100x50 actual pixels
        let rotated = UIImage(cgImage: base, scale: 1, orientation: .right)
        let fixed = rotated.normalizedUp()
        XCTAssertEqual(fixed.imageOrientation, .up)
        // A .right orientation swaps the visual axes.
        XCTAssertEqual(fixed.size.width, 50, accuracy: 1)
        XCTAssertEqual(fixed.size.height, 100, accuracy: 1)
    }
}
