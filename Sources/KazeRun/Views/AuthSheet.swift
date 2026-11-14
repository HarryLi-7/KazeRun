import SwiftUI

struct AuthSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var isCn: Bool = true
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var mfaCode: String = ""
    @State private var needsMfa: Bool = false
    @State private var isWorking: Bool = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("GARMIN CONNECT AUTH")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(KazeTheme.vermilion)
                    Text("连接佳明账号")
                        .font(.system(size: 20, weight: .bold))
                }
                Spacer()
                if appState.authStatus?.authenticated == true {
                    Button("关闭") { dismiss() }
                        .buttonStyle(.bordered)
                }
            }

            Text("凭据仅用于向 Garmin 官方 SSO 换取 OAuth Token，Token 安全保存在本机 Application Support 目录，不会上传任何第三方服务器。")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)

            Picker("账号区域", selection: $isCn) {
                Text("中国区 (garmin.cn)").tag(true)
                Text("国际区 (garmin.com)").tag(false)
            }
            .pickerStyle(.segmented)
            .disabled(needsMfa || isWorking)

            if !needsMfa {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Garmin 账号邮箱 / 手机号", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isWorking)

                    SecureField("登录密码", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isWorking)
                        .onSubmit {
                            Task { await performLogin() }
                        }
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("已触发两步验证（MFA），请查收邮箱或短信验证码：")
                        .font(.system(size: 12, weight: .medium))
                    TextField("6 位验证码", text: $mfaCode)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isWorking)
                        .onSubmit {
                            Task { await submitMfa() }
                        }
                }
            }

            if let errorText {
                Text(errorText)
                    .font(.system(size: 12))
                    .foregroundStyle(KazeTheme.vermilion)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(KazeTheme.vermilion.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(spacing: 10) {
                if !needsMfa {
                    Button {
                        Task { await performLogin() }
                    } label: {
                        if isWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("登录并验证")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KazeTheme.vermilion)
                    .disabled(isWorking || email.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
                } else {
                    Button("返回修改账号") {
                        needsMfa = false
                        mfaCode = ""
                        errorText = nil
                    }
                    .buttonStyle(.bordered)
                    .disabled(isWorking)

                    Button {
                        Task { await submitMfa() }
                    } label: {
                        if isWorking {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("提交验证码")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(KazeTheme.vermilion)
                    .disabled(isWorking || mfaCode.trimmingCharacters(in: .whitespaces).isEmpty)
                }

                Spacer()

                if appState.authStatus?.devImportAvailable == true && !needsMfa {
                    Button("导入本机已有 MCP Token") {
                        Task { await importDevTokens() }
                    }
                    .buttonStyle(.bordered)
                    .disabled(isWorking)
                }
            }
        }
        .padding(24)
        .frame(width: 460)
        .onAppear {
            if let existing = appState.authStatus {
                isCn = existing.isCn
                if let e = existing.email { email = e }
            }
        }
    }

    private func performLogin() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }

        do {
            let res = try await appState.bridge.callDictionary(
                method: "auth_login",
                params: ["email": email, "password": password, "is_cn": isCn]
            )
            if (res["status"] as? String) == "needs_mfa" {
                needsMfa = true
            } else {
                await appState.refreshAuthStatus()
                dismiss()
                await appState.syncAll()
            }
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func submitMfa() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }

        do {
            _ = try await appState.bridge.callDictionary(
                method: "auth_mfa",
                params: ["mfa_code": mfaCode]
            )
            await appState.refreshAuthStatus()
            dismiss()
            await appState.syncAll()
        } catch {
            errorText = error.localizedDescription
        }
    }

    private func importDevTokens() async {
        isWorking = true
        errorText = nil
        defer { isWorking = false }

        do {
            _ = try await appState.bridge.callDictionary(
                method: "auth_import_tokens",
                params: ["is_cn": true]
            )
            await appState.refreshAuthStatus()
            dismiss()
            await appState.syncAll()
        } catch {
            errorText = error.localizedDescription
        }
    }
}
