//
//  HomeView.swift
//  Phonaze_iPhone
//
//  Created by 강형준 on 3/17/25.
//

import SwiftUI

struct HomeView: View {
    var body: some View {
        VStack(spacing: 20) {
            Text("Connected! Choose an action:")
                .font(.headline)
                .padding()
            
            NavigationLink(destination: SelectView()) {
                Text("Go to SelectView")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
            }
            
            NavigationLink(destination: NumberScrollView()) {
                Text("Go to ScrollView")
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .navigationTitle("Home")
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            HomeView()
        }
    }
}
