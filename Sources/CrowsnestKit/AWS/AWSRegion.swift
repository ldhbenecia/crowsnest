import Foundation

enum AWSRegion {
    /// 설정 창에서 고를 수 있는 상용 리전 — 손으로 칠 때 나는 오타를 막으려고 목록으로 받음
    static let known: [(code: String, name: String)] = [
        ("ap-northeast-2", "서울"),
        ("ap-northeast-1", "도쿄"),
        ("ap-northeast-3", "오사카"),
        ("ap-east-1", "홍콩"),
        ("ap-southeast-1", "싱가포르"),
        ("ap-southeast-2", "시드니"),
        ("ap-southeast-3", "자카르타"),
        ("ap-southeast-4", "멜버른"),
        ("ap-south-1", "뭄바이"),
        ("ap-south-2", "하이데라바드"),
        ("us-east-1", "버지니아 북부"),
        ("us-east-2", "오하이오"),
        ("us-west-1", "캘리포니아 북부"),
        ("us-west-2", "오리건"),
        ("ca-central-1", "캐나다 중부"),
        ("ca-west-1", "캘거리"),
        ("sa-east-1", "상파울루"),
        ("eu-west-1", "아일랜드"),
        ("eu-west-2", "런던"),
        ("eu-west-3", "파리"),
        ("eu-central-1", "프랑크푸르트"),
        ("eu-central-2", "취리히"),
        ("eu-north-1", "스톡홀름"),
        ("eu-south-1", "밀라노"),
        ("eu-south-2", "스페인"),
        ("me-south-1", "바레인"),
        ("me-central-1", "아랍에미리트"),
        ("il-central-1", "텔아비브"),
        ("af-south-1", "케이프타운"),
    ]

    /// 서울 (ap-northeast-2) — 목록에 없는 리전은 코드만
    static func label(_ code: String) -> String {
        known.first { $0.code == code }.map { "\($0.name) (\(code))" } ?? code
    }

    /// ap-northeast-2 · us-gov-west-1 같은 모양만 — 호스트 이름에 들어가서 점 · 슬래시가 섞이면 안 됨
    static func isValid(_ region: String) -> Bool {
        // \d 는 다른 문자 체계의 숫자도 받아서 ASCII 숫자로 좁힘
        region.wholeMatch(of: /[a-z]{2}(-[a-z]+)+-[0-9]+/) != nil
    }
}
