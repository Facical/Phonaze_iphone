//
//  Phonaze_iPhoneApp.swift
//  Phonaze_iPhone
//
//  Created by 강형준 on 3/17/25.
//


import SwiftUI

@main
struct Phonaze_iPhoneApp: App {
    @StateObject private var connectivityManager = ConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(connectivityManager)
        }
    }
}
