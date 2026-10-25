//
//  QiblaCompassView.swift
//  Ramadan Pro
//

import SwiftUI
import CoreLocation
import Combine

struct QiblaCompassView: View {
    @StateObject private var compassManager = CompassManager()
    @StateObject private var hapticGenerator = HapticFeedbackGenerator()
    @State private var hasVibrated = false
    @EnvironmentObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                compassCard
                guidanceCard
                infoCard
            }
            .padding(20)
        }
        .background(AppColors.slCream.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            compassManager.startUpdates()
        }
        .onDisappear {
            compassManager.stopUpdates()
        }
        .onChange(of: compassManager.isAligned) { isAligned in
            if isAligned && !hasVibrated {
                hapticGenerator.triggerHeavyHaptic()
                hasVibrated = true
            } else if !isAligned {
                hasVibrated = false
            }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                Image("logo")
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Qibla")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(AppColors.slTextPrimary)
                    Text("Find the right direction for your salah.")
                        .font(.system(size: 13))
                        .foregroundColor(AppColors.slTextSecondary)
                }
            }
            Spacer()
            Button {
                appState.selectedTab = AppEnums.TabItem.profile.rawValue
            } label: {
                Circle()
                    .fill(AppColors.slGreen.opacity(0.16))
                    .frame(width: 38, height: 38)
                    .overlay(Image(systemName: "person.fill").foregroundColor(AppColors.slGreen))
            }
        }
    }

    private var compassCard: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColors.slGradientTop, AppColors.slDeepGreen],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 320, height: 320)
                    .shadow(color: AppColors.slGreen.opacity(0.25), radius: 16, x: 0, y: 8)

                ForEach(0..<36, id: \.self) { index in
                    Rectangle()
                        .fill(Color.white.opacity(index % 3 == 0 ? 0.75 : 0.45))
                        .frame(width: index % 3 == 0 ? 2 : 1, height: index % 3 == 0 ? 18 : 10)
                        .offset(y: index % 3 == 0 ? -140 : -145)
                        .rotationEffect(.degrees(Double(index) * 10))
                }

                if let qiblaBearing = compassManager.qiblaBearing {
                    let relativeAngle = shortestPathAngle(from: compassManager.heading, to: qiblaBearing)
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(AppColors.slGold)
                            .frame(width: 5, height: 126)
                            .overlay(alignment: .top) {
                                Triangle()
                                    .fill(AppColors.slGold)
                                    .frame(width: 22, height: 22)
                                    .offset(y: -10)
                            }
                        Spacer()
                    }
                    .frame(width: 320, height: 320)
                    .rotationEffect(.degrees(relativeAngle))
                    .animation(.linear(duration: 0.12), value: relativeAngle)
                }

                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                    .overlay(
                        VStack(spacing: 2) {
                            Text("Qibla")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(AppColors.slDeepGreen)
                            if let qiblaBearing = compassManager.qiblaBearing {
                                Text("\(Int(qiblaBearing))°")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(AppColors.slGold)
                            }
                        }
                    )
            }

            if compassManager.isAligned {
                Text("Aligned with Qibla")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(AppColors.slGreen)
            } else {
                Text(compassManager.turnDirection ?? L10n.text("Move your phone slowly to calibrate."))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.slTextPrimary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    private var guidanceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How to use it")
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(AppColors.slTextPrimary)
            Text("Hold your phone flat, rotate slowly, and follow the gold needle until it aligns.")
                .font(.system(size: 14))
                .foregroundColor(AppColors.slTextSecondary)
            if let distance = compassManager.distanceToMakkah {
                Text(L10n.format("%d km to the Kaaba", Int(distance / 1000)))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.slGold)
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private var infoCard: some View {
        VStack(spacing: 14) {
            infoRow(title: "City", value: compassManager.currentCity ?? "Locating…")
            infoRow(title: "Sensor accuracy", value: compassManager.precision)
            infoRow(title: "Alignment threshold", value: "5°")
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 6, x: 0, y: 2)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(L10n.text(title))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(AppColors.slTextSecondary)
            Spacer()
            Text(L10n.text(value))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(AppColors.slTextPrimary)
        }
    }

    private func shortestPathAngle(from heading: Double, to qiblaBearing: Double) -> Double {
        var angle = qiblaBearing - heading
        while angle > 180 { angle -= 360 }
        while angle < -180 { angle += 360 }
        return angle < 0 ? angle + 360 : angle
    }
}

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

class CompassManager: NSObject, ObservableObject {
    @Published var heading: Double = 0.0
    @Published var qiblaBearing: Double?
    @Published var distanceToMakkah: Double?
    @Published var precision: String = "High"
    @Published var currentCity: String?
    @Published var isAligned: Bool = false
    @Published var turnDirection: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private let makkahLatitude = 21.4225
    private let makkahLongitude = 39.8262
    private let alignmentThreshold: Double = 5.0

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        setupLocationUpdates()
    }

    func startUpdates() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 0
        locationManager.activityType = .otherNavigation
        locationManager.startUpdatingLocation()
        locationManager.headingFilter = 1.0
        locationManager.startUpdatingHeading()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            if let location = self?.locationManager.location {
                self?.calculateQibla(location: location)
            }
        }
    }

    func stopUpdates() {
        locationManager.stopUpdatingLocation()
        locationManager.stopUpdatingHeading()
    }

    private func setupLocationUpdates() {
        if let location = locationManager.location {
            calculateQibla(location: location)
        }
    }

    private func calculateQibla(location: CLLocation) {
        guard location.horizontalAccuracy > 0 && location.horizontalAccuracy < 1000 else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let bearing = self.calculateBearing(
                from: location.coordinate,
                to: CLLocationCoordinate2D(latitude: self.makkahLatitude, longitude: self.makkahLongitude)
            )
            self.qiblaBearing = bearing
            let makkahLocation = CLLocation(latitude: self.makkahLatitude, longitude: self.makkahLongitude)
            self.distanceToMakkah = location.distance(from: makkahLocation)
            self.precision = location.horizontalAccuracy < 10 ? "High" : (location.horizontalAccuracy < 50 ? "Medium" : "Low")
            self.getCityName(from: location)
            self.checkAlignment()
        }
    }

    private func checkAlignment() {
        guard let qiblaBearing else {
            isAligned = false
            turnDirection = nil
            return
        }
        var angle = qiblaBearing - heading
        while angle > 180 { angle -= 360 }
        while angle < -180 { angle += 360 }
        let angleDifference = abs(angle)
        isAligned = angleDifference <= alignmentThreshold
        if !isAligned {
            let degrees = Int(angleDifference.rounded())
            turnDirection = angle > 0 ? L10n.format("Turn right %d°", degrees) : L10n.format("Turn left %d°", degrees)
        } else {
            turnDirection = nil
        }
    }

    private func getCityName(from location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            guard let self else { return }
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self.currentCity = placemark.locality ?? placemark.subAdministrativeArea ?? "Unknown"
                }
            }
        }
    }

    private func calculateBearing(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) -> Double {
        let lat1 = from.latitude * .pi / 180.0
        let lat2 = to.latitude * .pi / 180.0
        let deltaLon = (to.longitude - from.longitude) * .pi / 180.0
        let y = sin(deltaLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(deltaLon)
        let bearing = atan2(y, x) * 180.0 / .pi
        return (bearing + 360.0).truncatingRemainder(dividingBy: 360.0)
    }
}

extension CompassManager: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        calculateQibla(location: location)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.heading = newHeading.trueHeading >= 0 ? newHeading.trueHeading : newHeading.magneticHeading
            self.checkAlignment()
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            if let location = manager.location {
                DispatchQueue.main.async { [weak self] in
                    self?.calculateQibla(location: location)
                }
            }
        default:
            break
        }
    }
}

class HapticFeedbackGenerator: ObservableObject {
    private let impactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private var isPrepared = false

    init() {
        prepareGenerators()
    }

    private func prepareGenerators() {
        impactGenerator.prepare()
        notificationGenerator.prepare()
        isPrepared = true
    }

    func triggerHeavyHaptic() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if !self.isPrepared {
                self.prepareGenerators()
            }
            self.notificationGenerator.notificationOccurred(.success)
            self.impactGenerator.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.prepareGenerators()
            }
        }
    }
}

#Preview {
    QiblaCompassView()
        .environmentObject(AppState.shared)
}
