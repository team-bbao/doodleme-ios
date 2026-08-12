//
//  DuddlemeApp.swift
//  Duddleme
//
//  Created by Apple Developer Academy on 8/6/26.
//

import SwiftUI


struct Viewpage: View {
    @State private var selectedTabIndex = 0

    var body: some View {
        TabView(selection: $selectedTabIndex){
            Tab("list", systemImage: "square.grid.2x2", value: 0) {
                Listpage()
            }


            Tab("Draw", systemImage: "pencil.tip", value: 1) {
                Drowingpage2(selectedTabIndex: $selectedTabIndex)
            }

        //    Tab("Scan", systemImage: "qrcode.viewfinder", value: 2) {
        //        QRScannerView()
        //    }

        }
        .tabViewStyle(.sidebarAdaptable)
        //.shadow(color: .black.opacity(0.5), radius: 4) -> 안되나봄 ㅎㅎ;;
    }
}

#Preview {
    Viewpage()
}
