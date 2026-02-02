import Foundation

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func isYesterday(of other: Date) -> Bool {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: other.startOfDay) else {
            return false
        }
        return Calendar.current.isDate(self, inSameDayAs: yesterday)
    }
}
