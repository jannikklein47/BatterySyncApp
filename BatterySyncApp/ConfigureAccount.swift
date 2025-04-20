//
//  ConfigureAccount.swift
//  BatterySyncApp
//
//  Created by Jannik Klein on 17.04.25.
//

import AppKit
import SwiftUI


struct ConfigureAccount: View {
    @State var email : String
    @State private var password = ""
    
    var onLogin: (_ email: String, _ password: String) -> Void
    var onCancel: (_ x : String) -> Void
    
    @State var loginFailed = false
    @State var loading = false
    
    @ViewBuilder
    var body: some View {
        VStack {
            TextField("Benutzername / E-Mail", text: $email)
                .textFieldStyle(.roundedBorder)
                .disabled(loading)
            SecureField("Passwort", text: $password)
                .textFieldStyle(.roundedBorder)
                .disabled(loading)
            HStack {
                Button("Speichern") {
                    //saveCredentials(email: email, password: password)
                    onLogin(email, password)
                    loginFailed = false
                    loading = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        loginFailed = true
                        print("Timer abgelaufen")
                        loading = false
                    }
                }.disabled(loading)
                
                Button("Abbrechen") {
                    onCancel("")
                }
            }
            
            
            if (loginFailed) {
                Text("Login fehlgeschlagen").foregroundStyle(Color.orange)
            }
        }
        .padding()
        .frame(width: 300)
    }

}

struct ConfigureAccountLoginState {
    var loginFailed : Bool
}
