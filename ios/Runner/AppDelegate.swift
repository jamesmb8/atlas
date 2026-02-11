import UIKit
import Flutter
import MapKit

@main
@objc class AppDelegate: FlutterAppDelegate {

  private let channelName = "atlas/mapkit_search"

  private let completer = MKLocalSearchCompleter()
  private var autocompleteContinuation: CheckedContinuation<[[String: Any]], Error>?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {

    let controller = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: controller.binaryMessenger)

    completer.resultTypes = [.address, .pointOfInterest]
    completer.delegate = self

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }

      switch call.method {

      case "autocomplete":
        guard
          let args = call.arguments as? [String: Any],
          let query = args["query"] as? String
        else {
          result(FlutterError(code: "bad_args", message: "Missing query", details: nil))
          return
        }

        Task {
          do {
            let items = try await self.autocomplete(query: query)
            result(items)
          } catch {
            result(FlutterError(code: "autocomplete_failed", message: "\(error)", details: nil))
          }
        }

      case "resolve":
        guard
          let args = call.arguments as? [String: Any],
          let title = args["title"] as? String,
          let subtitle = args["subtitle"] as? String
        else {
          result(FlutterError(code: "bad_args", message: "Missing title/subtitle", details: nil))
          return
        }

        Task {
          do {
            let resolved = try await self.resolve(title: title, subtitle: subtitle)
            result(resolved)
          } catch {
            result(FlutterError(code: "resolve_failed", message: "\(error)", details: nil))
          }
        }

      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func autocomplete(query: String) async throws -> [[String: Any]] {
    // Cancel any pending continuation
    autocompleteContinuation?.resume(throwing: NSError(domain: "atlas", code: 1, userInfo: [NSLocalizedDescriptionKey: "Cancelled"]))
    autocompleteContinuation = nil

    return try await withCheckedThrowingContinuation { cont in
      self.autocompleteContinuation = cont
      self.completer.queryFragment = query
    }
  }

  private func resolve(title: String, subtitle: String) async throws -> [String: Any] {
    let query = "\(title) \(subtitle)".trimmingCharacters(in: .whitespacesAndNewlines)

    let request = MKLocalSearch.Request()
    request.naturalLanguageQuery = query

    let search = MKLocalSearch(request: request)
    let response = try await search.start()

    guard let item = response.mapItems.first, let coord = item.placemark.location?.coordinate else {
      throw NSError(domain: "atlas", code: 2, userInfo: [NSLocalizedDescriptionKey: "No coordinate found"])
    }

    return [
      "title": title,
      "subtitle": subtitle,
      "lat": coord.latitude,
      "lng": coord.longitude
    ]
  }
}

extension AppDelegate: MKLocalSearchCompleterDelegate {
  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    let items = completer.results.prefix(12).map { r in
      return [
        "title": r.title,
        "subtitle": r.subtitle
      ]
    }

    autocompleteContinuation?.resume(returning: Array(items))
    autocompleteContinuation = nil
  }

  func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
    autocompleteContinuation?.resume(throwing: error)
    autocompleteContinuation = nil
  }
}
