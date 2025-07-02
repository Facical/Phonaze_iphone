//
//  ContentView.swift
//  Phonaze_iPhone
//
//  Created by 강형준 on 3/17/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Welcome to Phonaze_iPhone")
                    .font(.headline)
                    .padding()
                
                NavigationLink(destination: ConnectionView()) {
                    Text("Connect to Vision Pro")
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
            }
            .navigationTitle("Main")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
