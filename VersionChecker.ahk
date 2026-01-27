; ##############################
; #   GitHub 版本檢測模組 v2.0  #
; ##############################
;
; 📌 模組說明
;   這是一個輕量級的版本檢測工具，用於檢查 GitHub Releases 的最新版本。
;   支援版本比較、下載連結生成、發行說明擷取。
;
; 📦 適用場景
;   - 自動檢測軟體是否有新版本
; - 顯示版本更新說明
; - 引導使用者前往下載頁面
;
; 🔗 相關連結
;   GitHub：https://github.com/Sid-1996/Sid-gun
;   原始碼：https://github.com/Sid-1996/Sid-gun/releases
;
; 🚀 快速使用
;   result := CheckForUpdates("v1.0.0", "Sid-1996", "Sid-gun")
;
;   if (result.NewVersionAvailable) {
;       MsgBox("發現新版本：" . result.LatestVersion)
;   }
;
; ⚙️ 關於 GitHub Token（可選）
;   - 免費帳號每小時可請求 60 次
;   - 填入 Token 可提高速率限制至 5,000 次/小時
;   - 一般使用情境下，不需要填寫 Token
;
; 📊 返回結果說明
;   result.Success              → 是否成功執行
;   result.NewVersionAvailable → 是否有新版本
;   result.LatestVersion       → 最新版本號
;   result.CurrentVersion      → 目前版本號
;   result.DownloadURL         → 下載頁面連結
;   result.ReleaseNotes        → 版本更新說明
;   result.PublishedAt         → 發布時間
;   result.Error               → 錯誤訊息（如有）
;

class VersionChecker {
    
    ; ===== 內部屬性 =====
    CurrentVersion := ""       ; 目前安裝的版本
    Owner := ""                ; GitHub 帳號名稱
    Repo := ""                 ; 倉庫名稱
    GitHubToken := ""          ; GitHub API Token（可選）
    ReleasesAPI := "https://api.github.com/repos/{owner}/{repo}/releases/latest"
    ReleasesURL := "https://github.com/{owner}/{repo}/releases"
    
    ; 🏗️ 構造函數
    ; @param currentVer 目前安裝的版本號（如 "v1.0.0"）
    ; @param owner      GitHub 帳號名稱（如 "Sid-1996"）
    ; @param repo       倉庫名稱（如 "Sid-gun"）
    ; @param token      GitHub API Token（可選）
    __New(currentVer, owner, repo, token := "") {
        this.CurrentVersion := currentVer
        this.Owner := owner
        this.Repo := repo
        this.GitHubToken := token
    }
    
    ; 🔍 檢查更新
    ; @returns 回傳包含版本資訊的物件
    CheckForUpdates() {
        local result := {}
        
        try {
            ; 1️⃣ 組裝 API 網址
            apiUrl := StrReplace(this.ReleasesAPI, "{owner}", this.Owner)
            apiUrl := StrReplace(apiUrl, "{repo}", this.Repo)
            
            ; 2️⃣ 發送 HTTP 請求
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", apiUrl, false)
            http.SetRequestHeader("User-Agent", "AutoHotkey-VersionChecker/2.0")
            
            ; 3️⃣ 添加認證（如果有提供 Token）
            if (this.GitHubToken != "") {
                http.SetRequestHeader("Authorization", "token " . this.GitHubToken)
            }
            
            ; 4️⃣ 設定超時（5秒連線、5秒接收、10秒總時間）
            http.SetTimeouts(5000, 5000, 10000, 10000)
            http.Send()
            
            ; 5️⃣ 檢查 HTTP 狀態碼
            if (http.Status != 200) {
                result.Success := false
                result.NewVersionAvailable := false
                
                switch http.Status {
                    case 403:
                        result.Error := "⚠️ API 請求次數已達上限（免費帳號每小時 60 次）`n`n請稍後再試，或考慮使用 GitHub Token。"
                    case 404:
                        result.Error := "⚠️ 找不到指定的 GitHub 倉庫`n`n請檢查 Owner 或 Repo 名稱是否正確。"
                    default:
                        result.Error := "⚠️ HTTP 錯誤 " . http.Status
                }
                return result
            }
            
            ; 6️⃣ 解析回應資料
            responseText := http.ResponseText
            parsedData := this._ParseJSON(responseText)
            
            ; 7️⃣ 提取版本資訊
            try {
                latestVersion := parsedData.tag_name
                if (!latestVersion) {
                    result.Success := false
                    result.Error := "⚠️ 無法解析版本號"
                    result.NewVersionAvailable := false
                    return result
                }
            } catch as e {
                result.Success := false
                result.Error := "⚠️ 解析版本失敗: " . e.Message
                result.NewVersionAvailable := false
                return result
            }
            
            ; 8️⃣ 比較版本
            newVersionAvailable := this._CompareVersions(latestVersion, this.CurrentVersion)
            
            ; 9️⃣ 回傳結果
            result.Success := true
            result.NewVersionAvailable := newVersionAvailable
            result.LatestVersion := latestVersion
            result.CurrentVersion := this.CurrentVersion
            result.DownloadURL := this._GetDownloadURL()
            result.ReleaseNotes := parsedData.body ? parsedData.body : "（無版本說明）"
            result.PublishedAt := parsedData.published_at ? parsedData.published_at : ""
            result.PreRelease := parsedData.prerelease ? true : false
            
            return result
            
        } catch as e {
            result.Success := false
            result.Error := "❌ 請求失敗: " . e.Message
            result.NewVersionAvailable := false
            return result
        }
    }
    
    ; 📄 解析 JSON（使用正則表達式，相容性更好）
    _ParseJSON(jsonText) {
        local data := {}
        
        try {
            ; 提取 tag_name
            local match1
            if (RegExMatch(jsonText, '"tag_name"\s*:\s*"([^"]+)"', &match1)) {
                data.tag_name := match1[1]
            }
            
            ; 提取 body
            local match2
            if (RegExMatch(jsonText, '"body"\s*:\s*"([^"]*)"', &match2)) {
                ; 清理轉義字符
                cleaned := StrReplace(match2[1], "\r\n", "`n")
                cleaned := StrReplace(cleaned, "\\n", "`n")
                cleaned := StrReplace(cleaned, '\"', '"')
                data.body := cleaned
            }
            
            ; 提取 published_at
            local match3
            if (RegExMatch(jsonText, '"published_at"\s*:\s*"([^"]+)"', &match3)) {
                data.published_at := match3[1]
            }
            
            ; 提取 prerelease
            local match4
            if (RegExMatch(jsonText, '"prerelease"\s*:\s*(true|false)', &match4)) {
                data.prerelease := (match4[1] == "true")
            }
            
            return data
            
        } catch as e {
            return { error: "JSON 解析失敗: " . e.Message }
        }
    }
    
    ; 🔗 獲取下載頁面網址
    _GetDownloadURL() {
        url := StrReplace(this.ReleasesURL, "{owner}", this.Owner)
        url := StrReplace(url, "{repo}", this.Repo)
        return url
    }
    
    ; ⚖️ 比較版本號
    ; @return true 表示有新版本
    _CompareVersions(newVersion, currentVersion) {
        ; 移除 v 前綴
        newVer := StrReplace(newVersion, "v", "")
        currVer := StrReplace(currentVersion, "v", "")
        
        ; 分割為數字陣列
        newParts := StrSplit(newVer, ".")
        currParts := StrSplit(currVer, ".")
        
        ; 補齊位數
        maxLen := Max(newParts.Length, currParts.Length)
        Loop maxLen {
            if (!newParts.Has(A_Index))
                newParts[A_Index] := "0"
            if (!currParts.Has(A_Index))
                currParts[A_Index] := "0"
        }
        
        ; 逐位比較
        Loop newParts.Length {
            newNum := Integer(newParts[A_Index])
            currNum := Integer(currParts[A_Index])
            
            if (newNum > currNum)
                return true
            else if (newNum < currNum)
                return false
        }
        
        return false
    }
}

; ═══════════════════════════════════════════════════════
; 🌍 全域函數接口（方便直接使用）
; ═══════════════════════════════════════════════════════

; 🔧 檢查更新
; @param currentVersion 目前版本號
; @param repoOwner      GitHub 帳號
; @param repoName       倉庫名稱
; @param githubToken    Token（可選）
; @returns 版本資訊物件
CheckForUpdates(currentVersion, repoOwner, repoName, githubToken := "") {
    checker := VersionChecker(currentVersion, repoOwner, repoName, githubToken)
    return checker.CheckForUpdates()
}

; ═══════════════════════════════════════════════════════
; 📘 使用範例（可直接複製使用）
; ═══════════════════════════════════════════════════════
/*
; ┌─────────────────────────────────────────────────┐
; │ 範例：完整的版本檢查流程                          │
; └─────────────────────────────────────────────────┘

; 1️⃣ 檢查更新
result := CheckForUpdates("v1.0.0", "Sid-1996", "Sid-gun")

; 2️⃣ 處理錯誤
if (!result.Success) {
    MsgBox("❌ 版本檢測失敗：`n`n" . result.Error, "錯誤", 16)
    return
}

; 3️⃣ 顯示結果
if (result.NewVersionAvailable) {
    ; 發現新版本
    msg := "🚀 發現新版本！`n`n"
    msg .= "📌 當前版本：" . result.CurrentVersion . "`n"
    msg .= "✨ 最新版本：" . result.LatestVersion . "`n"
    msg .= "📅 發布時間：" . result.PublishedAt . "`n`n"
    msg .= "📝 更新說明：`n" . result.ReleaseNotes . "`n`n"
    msg .= "─────────────────────────────`n"
    msg .= "點擊 [OK] 前往下載頁面`n"
    msg .= "點擊 [Cancel] 稍後更新"
    
    if (MsgBox(msg, "🔔 版本更新通知", 1) == "OK") {
        Run(result.DownloadURL)
    }
} else {
    ; 已是最新版本
    MsgBox("✅ 您正在使用最新版本：`n" . result.CurrentVersion, "版本檢測", 64)
}
*/
