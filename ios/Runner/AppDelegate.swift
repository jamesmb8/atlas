// ios/Runner/AppDelegate.swift
import UIKit
import Flutter
import MapKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let searchChannelName = "atlas/mapkit_search"
  private let routeChannelName = "atlas/mapkit_directions"

  private let completer = MKLocalSearchCompleter()
  private var autocompleteContinuation: CheckedContinuation<[[String: Any]], Error>?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller = window?.rootViewController as! FlutterViewController

    let searchChannel = FlutterMethodChannel(
      name: searchChannelName,
      binaryMessenger: controller.binaryMessenger
    )

    let routeChannel = FlutterMethodChannel(
      name: routeChannelName,
      binaryMessenger: controller.binaryMessenger
    )

    completer.resultTypes = [.address, .pointOfInterest]
    completer.delegate = self

    searchChannel.setMethodCallHandler { [weak self] call, result in
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

    routeChannel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }

      switch call.method {
      case "route":
        guard
          let args = call.arguments as? [String: Any],
          let originLat = args["originLat"] as? CLLocationDegrees,
          let originLng = args["originLng"] as? CLLocationDegrees,
          let destLat = args["destLat"] as? CLLocationDegrees,
          let destLng = args["destLng"] as? CLLocationDegrees,
          let transportRaw = args["transport"] as? String
        else {
          result(FlutterError(code: "bad_args", message: "Missing route arguments", details: nil))
          return
        }

        Task {
          do {
            let points = try await self.routePolyline(
              originLat: originLat,
              originLng: originLng,
              destLat: destLat,
              destLng: destLng,
              transportRaw: transportRaw
            )
            result(points)
          } catch {
            result(FlutterError(code: "route_failed", message: "\(error)", details: nil))
          }
        }

      case "summary":
        guard
          let args = call.arguments as? [String: Any],
          let originLat = args["originLat"] as? CLLocationDegrees,
          let originLng = args["originLng"] as? CLLocationDegrees,
          let destLat = args["destLat"] as? CLLocationDegrees,
          let destLng = args["destLng"] as? CLLocationDegrees,
          let transportRaw = args["transport"] as? String
        else {
          result(FlutterError(code: "bad_args", message: "Missing summary arguments", details: nil))
          return
        }

        Task {
          do {
            let summary = try await self.routeSummary(
              originLat: originLat,
              originLng: originLng,
              destLat: destLat,
              destLng: destLng,
              transportRaw: transportRaw
            )
            result(summary)
          } catch {
            result(FlutterError(code: "summary_failed", message: "\(error)", details: nil))
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
    autocompleteContinuation?.resume(
      throwing: NSError(
        domain: "atlas",
        code: 1,
        userInfo: [NSLocalizedDescriptionKey: "Cancelled"]
      )
    )
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

    guard let item = response.mapItems.first,
          let coord = item.placemark.location?.coordinate else {
      throw NSError(
        domain: "atlas",
        code: 2,
        userInfo: [NSLocalizedDescriptionKey: "No coordinate found"]
      )
    }

    return [
      "title": item.name ?? title,
      "subtitle": subtitle,
      "lat": coord.latitude,
      "lng": coord.longitude
    ]
  }

  private func makeDirectionsRequest(
    originLat: CLLocationDegrees,
    originLng: CLLocationDegrees,
    destLat: CLLocationDegrees,
    destLng: CLLocationDegrees,
    transportRaw: String
  ) -> MKDirections.Request {
    let sourcePlacemark = MKPlacemark(
      coordinate: CLLocationCoordinate2D(latitude: originLat, longitude: originLng)
    )
    let destinationPlacemark = MKPlacemark(
      coordinate: CLLocationCoordinate2D(latitude: destLat, longitude: destLng)
    )

    let request = MKDirections.Request()
    request.source = MKMapItem(placemark: sourcePlacemark)
    request.destination = MKMapItem(placemark: destinationPlacemark)

    switch transportRaw.lowercased() {
    case "walking":
      request.transportType = .walking
    case "automobile", "driving":
      request.transportType = .automobile
    default:
      request.transportType = .automobile
    }

    return request
  }

  private func routePolyline(
    originLat: CLLocationDegrees,
    originLng: CLLocationDegrees,
    destLat: CLLocationDegrees,
    destLng: CLLocationDegrees,
    transportRaw: String
  ) async throws -> [[String: Double]] {
    let request = makeDirectionsRequest(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      transportRaw: transportRaw
    )

    let response = try await MKDirections(request: request).calculate()

    guard let route = response.routes.first else {
      throw NSError(
        domain: "atlas",
        code: 4,
        userInfo: [NSLocalizedDescriptionKey: "No route found"]
      )
    }

    let polyline = route.polyline
    let pointCount = polyline.pointCount
    var coords = Array(
      repeating: CLLocationCoordinate2D(latitude: 0, longitude: 0),
      count: pointCount
    )

    polyline.getCoordinates(&coords, range: NSRange(location: 0, length: pointCount))

    return coords.map { coordinate in
      [
        "lat": coordinate.latitude,
        "lng": coordinate.longitude
      ]
    }
  }

  private func routeSummary(
    originLat: CLLocationDegrees,
    originLng: CLLocationDegrees,
    destLat: CLLocationDegrees,
    destLng: CLLocationDegrees,
    transportRaw: String
  ) async throws -> [String: Any] {
    let request = makeDirectionsRequest(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
      transportRaw: transportRaw
    )

    let response = try await MKDirections(request: request).calculate()

    guard let route = response.routes.first else {
      throw NSError(
        domain: "atlas",
        code: 5,
        userInfo: [NSLocalizedDescriptionKey: "No route summary found"]
      )
    }

    return [
      "distanceMeters": route.distance,
      "durationMinutes": Int((route.expectedTravelTime / 60.0).rounded())
    ]
  }
}

extension AppDelegate: MKLocalSearchCompleterDelegate {
  func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
    let items = completer.results.prefix(12).map { result in
      [
        "title": result.title,
        "subtitle": result.subtitle
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
