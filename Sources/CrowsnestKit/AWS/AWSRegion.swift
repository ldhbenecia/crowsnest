import Foundation

enum AWSRegion {
    /// 설정 창에서 고를 수 있는 상용 리전 — 손으로 칠 때 나는 오타를 막으려고 목록으로 받음
    static let known: [(code: String, korean: String, english: String)] = [
        ("ap-northeast-2", "서울", "Seoul"),
        ("ap-northeast-1", "도쿄", "Tokyo"),
        ("ap-northeast-3", "오사카", "Osaka"),
        ("ap-east-1", "홍콩", "Hong Kong"),
        ("ap-southeast-1", "싱가포르", "Singapore"),
        ("ap-southeast-2", "시드니", "Sydney"),
        ("ap-southeast-3", "자카르타", "Jakarta"),
        ("ap-southeast-4", "멜버른", "Melbourne"),
        ("ap-south-1", "뭄바이", "Mumbai"),
        ("ap-south-2", "하이데라바드", "Hyderabad"),
        ("us-east-1", "버지니아 북부", "N. Virginia"),
        ("us-east-2", "오하이오", "Ohio"),
        ("us-west-1", "캘리포니아 북부", "N. California"),
        ("us-west-2", "오리건", "Oregon"),
        ("ca-central-1", "캐나다 중부", "Canada Central"),
        ("ca-west-1", "캘거리", "Calgary"),
        ("sa-east-1", "상파울루", "São Paulo"),
        ("eu-west-1", "아일랜드", "Ireland"),
        ("eu-west-2", "런던", "London"),
        ("eu-west-3", "파리", "Paris"),
        ("eu-central-1", "프랑크푸르트", "Frankfurt"),
        ("eu-central-2", "취리히", "Zurich"),
        ("eu-north-1", "스톡홀름", "Stockholm"),
        ("eu-south-1", "밀라노", "Milan"),
        ("eu-south-2", "스페인", "Spain"),
        ("me-south-1", "바레인", "Bahrain"),
        ("me-central-1", "아랍에미리트", "UAE"),
        ("il-central-1", "텔아비브", "Tel Aviv"),
        ("af-south-1", "케이프타운", "Cape Town"),
    ]

    /// 서울 (ap-northeast-2) — 목록에 없는 리전은 코드만
    static func label(_ code: String) -> String {
        known.first { $0.code == code }.map { "\(L($0.korean, $0.english)) (\(code))" } ?? code
    }

    /// ap-northeast-2 · us-gov-west-1 같은 모양만 — 호스트 이름에 들어가서 점 · 슬래시가 섞이면 안 됨
    static func isValid(_ region: String) -> Bool {
        // \d 는 다른 문자 체계의 숫자도 받아서 ASCII 숫자로 좁힘
        region.wholeMatch(of: /[a-z]{2}(-[a-z]+)+-[0-9]+/) != nil
    }
}
