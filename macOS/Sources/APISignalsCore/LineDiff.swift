import Foundation

public enum DiffLine: Sendable {
    case unchanged(String)
    case added(String)
    case removed(String)
}

public enum LineDiff {
    /// Myers LCS-based line diff returning a flat sequence of DiffLine.
    public static func diff(old: String, new: String) -> [DiffLine] {
        let oldLines = old.components(separatedBy: "\n")
        let newLines = new.components(separatedBy: "\n")
        let lcs = longestCommonSubsequence(oldLines, newLines)
        return buildDiff(old: oldLines, new: newLines, lcs: lcs)
    }

    private static func longestCommonSubsequence(_ a: [String], _ b: [String]) -> [[Int]] {
        let m = a.count, n = b.count
        var dp = Array(repeating: Array(repeating: 0, count: n + 1), count: m + 1)
        for i in 1...max(m, 1) where i <= m {
            for j in 1...max(n, 1) where j <= n {
                if a[i - 1] == b[j - 1] {
                    dp[i][j] = dp[i - 1][j - 1] + 1
                } else {
                    dp[i][j] = max(dp[i - 1][j], dp[i][j - 1])
                }
            }
        }
        return dp
    }

    private static func buildDiff(old: [String], new: [String], lcs: [[Int]]) -> [DiffLine] {
        var result: [DiffLine] = []
        var i = old.count, j = new.count
        var stack: [DiffLine] = []

        while i > 0 || j > 0 {
            if i > 0 && j > 0 && old[i - 1] == new[j - 1] {
                stack.append(.unchanged(old[i - 1]))
                i -= 1; j -= 1
            } else if j > 0 && (i == 0 || lcs[i][j - 1] >= lcs[i - 1][j]) {
                stack.append(.added(new[j - 1]))
                j -= 1
            } else {
                stack.append(.removed(old[i - 1]))
                i -= 1
            }
        }

        result = stack.reversed()
        return result
    }
}
