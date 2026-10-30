// Static discussion map. Render on macOS; not part of the game package.
// swift -module-cache-path /tmp/civ5-diagram-module-cache dev-utils/victory-overview.swift
import AppKit

let width = 1800, height = 2040
let destination = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "docs/images/science-victory-overview.png"
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
let context = NSGraphicsContext(bitmapImageRep: bitmap)!.cgContext
context.translateBy(x: 0, y: CGFloat(height)); context.scaleBy(x: 1, y: -1)
NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: true)

func color(_ value: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((value >> 16) & 255) / 255,
        green: CGFloat((value >> 8) & 255) / 255, blue: CGFloat(value & 255) / 255, alpha: 1)
}
let ink = color(0x17263C), muted = color(0x53647A), blue = color(0x205BB6)
let orange = color(0xA34F19), purple = color(0x7040AA), green = color(0x16704C)
func rounded(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ fill: NSColor,
             border: NSColor? = nil, radius: CGFloat = 18) {
    let path = NSBezierPath(roundedRect: NSRect(x: x, y: y, width: w, height: h),
                           xRadius: radius, yRadius: radius)
    fill.setFill(); path.fill()
    if let stroke = border { stroke.setStroke(); path.lineWidth = 1.5; path.stroke() }
}
@discardableResult func text(_ value: String, _ x: CGFloat, _ y: CGFloat, _ w: CGFloat,
                            _ h: CGFloat, size: CGFloat = 28, weight: NSFont.Weight = .regular,
                            tint: NSColor = ink, align: NSTextAlignment = .left) -> CGFloat {
    let paragraph = NSMutableParagraphStyle()
    paragraph.lineSpacing = 5; paragraph.alignment = align
    paragraph.lineBreakMode = .byWordWrapping
    let attributed = NSAttributedString(string: value, attributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: tint, .paragraphStyle: paragraph])
    let measured = attributed.boundingRect(with: NSSize(width: w, height: 2000),
        options: [.usesLineFragmentOrigin, .usesFontLeading]).height
    precondition(measured <= h + 2, "Text overflows: \(value) (\(measured) > \(h))")
    attributed.draw(with: NSRect(x: x, y: y, width: w, height: h),
                    options: [.usesLineFragmentOrigin, .usesFontLeading])
    return measured
}
func arrow(_ x: CGFloat, _ top: CGFloat, _ bottom: CGFloat, _ tint: NSColor) {
    let p = NSBezierPath(); p.move(to: NSPoint(x: x, y: top)); p.line(to: NSPoint(x: x, y: bottom))
    p.move(to: NSPoint(x: x - 7, y: bottom - 8)); p.line(to: NSPoint(x: x, y: bottom))
    p.line(to: NSPoint(x: x + 7, y: bottom - 8)); tint.setStroke(); p.lineWidth = 2.5; p.stroke()
}
let margin: CGFloat = 54, gap: CGFloat = 24, col: CGFloat = 548
let columns: [CGFloat] = [54, 626, 1198]
func card(_ column: Int, _ y: CGFloat, _ h: CGFloat, _ title: String, _ body: String,
          titleHeight: CGFloat = 40, tint: NSColor = ink) {
    let x = columns[column] + 16
    rounded(x, y, col - 32, h, .white, border: color(0xDDE4ED), radius: 15)
    text(title, x + 22, y + 18, col - 76, titleHeight, size: 29, weight: .semibold, tint: tint)
    text(body, x + 22, y + 20 + titleHeight, col - 76, h - titleHeight - 34, size: 27)
}

rounded(0, 0, CGFloat(width), CGFloat(height), color(0xF7F9FC), radius: 0)
text("Три пути научной победы", 54, 42, 1692, 80, size: 60, weight: .bold)
text("civ5-refined  /  карта обсуждения  /  31 октября 2026", 57, 126, 1680, 45, size: 29, tint: muted)
rounded(54, 188, 1692, 63, color(0xE9EFF8), radius: 13)
text("ЭТО ПРОЕКТ: новые финалы ещё не внедрены в игровую сборку v7", 78, 202, 1640, 40,
     size: 27, weight: .semibold)
text("База расчёта: 7 городов · 1000 науки империи/ход · средняя промышленность", 57, 270,
     1690, 43, size: 28, tint: muted)

let fills = [color(0xEEF4FF), color(0xFFF4E9), color(0xF5F0FD)]
let accents = [blue, orange, purple]
for i in 0..<3 { rounded(columns[i], 335, col, 1120, fills[i], radius: 22) }
text("А · КОСМИЧЕСКИЙ ПУТЬ", columns[0] + 23, 359, col - 46, 36, size: 24, weight: .semibold, tint: blue)
text("Межзвёздная\nэкспедиция", columns[0] + 23, 402, col - 46, 100, size: 39, weight: .bold)
text("Цель: Альфа Центавра", columns[0] + 23, 498, col - 46, 42, size: 26, tint: muted)
text("Б · КОСМИЧЕСКИЙ ПУТЬ", columns[1] + 23, 359, col - 46, 36, size: 24, weight: .semibold, tint: orange)
text("Колонизация\nМарса", columns[1] + 23, 402, col - 46, 100, size: 39, weight: .bold)
text("Четыре последовательных проекта", columns[1] + 23, 498, col - 46, 42, size: 26, tint: muted)
text("В · ВЫЧИСЛИТЕЛЬНЫЙ ПУТЬ", columns[2] + 23, 359, col - 46, 36, size: 24, weight: .semibold, tint: purple)
text("Технологическая\nсингулярность", columns[2] + 23, 402, col - 46, 100, size: 39, weight: .bold)
text("Прикладной ИИ → развитие вычислений", columns[2] + 23, 498, col - 46, 42, size: 26, tint: muted)

card(0, 560, 145, "Ракетная техника → Аполлон", "Программа: 750 производства.", tint: blue)
arrow(columns[0] + col / 2, 711, 728, blue)
card(0, 740, 180, "Пять привычных деталей", "3 ускорителя + кабина + стазис.\nСтроятся параллельно.\nКаждая часть: 1500 производства.", tint: blue)
arrow(columns[0] + col / 2, 926, 941, blue)
card(0, 950, 198, "Физика элементарных частиц\n+ ядерный синтез", "→ Перспективные двигатели\n→ Шестая деталь: двигатель.", titleHeight: 76, tint: blue)
card(0, 1170, 217, "Верфь — отдельная ветка", "Спутники → орбитальная\nинфраструктура: 6000 науки.\nЗдание: 500 производства.\nБонус +20%; +50% обсуждаем.", tint: blue)
text("ОТКРЫТО: двигатель и верфь", columns[0] + 26, 1390, col - 52, 65,
     size: 25, weight: .semibold, tint: orange)

card(1, 560, 160, "1. Разведка Марса", "Автономные космические системы.\nПроект: 500 производства.", tint: orange)
arrow(columns[1] + col / 2, 727, 743, orange)
card(1, 750, 155, "2. Транспортная система", "Орбитальная инфраструктура.\nПроект: 600 производства.", tint: orange)
arrow(columns[1] + col / 2, 912, 928, orange)
card(1, 935, 155, "3. Жилой комплекс", "Замкнутые биосистемы.\nПроект: 800 производства.", tint: orange)
arrow(columns[1] + col / 2, 1097, 1113, orange)
card(1, 1120, 160, "4. Самодостаточная колония", "Прикладной ИИ + дата-центр.\nПроект: 1000 производства.", tint: orange)
text("ВЫБРАН ОРИЕНТИР:\nМарс немного раньше корабля.\nТочные цены ещё предварительные.", columns[1] + 26, 1310, col - 52, 120,
     size: 25, weight: .medium, tint: green)

card(2, 560, 181, "Передовые вычислительные\nсистемы · 8400 науки", "Суперцентр: 1200 производства.\nОдин на империю; 20 золота/ход.", titleHeight: 76, tint: purple)
arrow(columns[2] + col / 2, 742, 758, purple)
card(2, 765, 145, "Общий ИИ · 9500 науки", "«Универсальный ИИ» — проект.\n1000 производства.", tint: purple)
arrow(columns[2] + col / 2, 917, 933, purple)
card(2, 940, 159, "Рекурсивное\nсамоусовершенствование", "10000 науки. Параллельно проекту.", titleHeight: 76, tint: purple)
arrow(columns[2] + col / 2, 1102, 1118, purple)
card(2, 1125, 185, "Рекурсивное обучение", "Наука городов → общий прогресс.\nОчередь строительства занята.\nУчаствуют города с дата-центрами.", tint: purple)
rounded(columns[2] + 16, 1320, col - 32, 105, color(0xE3F3EA), radius: 15)
text("13 666", columns[2] + 38, 1333, 235, 78, size: 54, weight: .bold, tint: green)
text("Порог обучения\nВЫБРАН", columns[2] + 279, 1340, 230, 70, size: 25, weight: .semibold, tint: green)

rounded(54, 1478, 1692, 64, color(0x17263C), radius: 15)
text("ТРИ МАРШРУТА → ОДНА НАУЧНАЯ ПОБЕДА", 78, 1492, 1640, 40,
     size: 28, weight: .semibold, tint: .white, align: .center)
text("Оставшиеся ходы в условной модели — не игровой замер", 57, 1560, 1680, 42, size: 28, tint: muted)
for (i, value) in ["115", "111", "112"].enumerated() {
    text(value, columns[i] + 24, 1610, 190, 83, size: 65, weight: .bold, tint: accents[i])
}
text("Корабль без верфи", columns[0] + 220, 1631, 315, 42, size: 27)
text("Марс", columns[1] + 220, 1631, 315, 42, size: 27)
text("Сингулярность", columns[2] + 220, 1631, 315, 42, size: 27)
rounded(54, 1710, 1692, 103, color(0xFFF0DA), radius: 15)
text("СХЕМА ПОДДЕРЖАНА: разведка Марса — 500; технологии сингулярности слегка дороже.\nОТКРЫТО: баланс межзвёздного пути и доступность верфи (+50% пока обсуждаем).",
     77, 1727, 1646, 77, size: 27, weight: .medium, tint: color(0x754414))

rounded(54, 1835, 1692, 137, .white, border: color(0xDDE4ED), radius: 15)
text("Отдельно: военная ветка", 77, 1851, 1600, 37, size: 28, weight: .semibold)
text("Прикладной ИИ + мобильная тактика → «Сетецентрическая война» → Центр боевого управления.\nДля чуда нужен дата-центр. Особое повышение войскам: +1 обзор и +10% боевой силы.",
     77, 1895, 1646, 70, size: 26)
text("Выбранные решения выделены зелёным. Остальные числа — предложения. Это общий план, не полный граф технологий.",
     57, 1992, 1685, 35, size: 23, tint: muted)

try FileManager.default.createDirectory(at: URL(fileURLWithPath: destination).deletingLastPathComponent(),
                                       withIntermediateDirectories: true)
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: destination))
print(destination)
