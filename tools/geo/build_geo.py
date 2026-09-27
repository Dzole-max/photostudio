"""Builds the compact geo assets used by map pages, map covers and the fake
geocoder from Natural Earth (public domain, naturalearthdata.com).

Usage: python tools/geo/build_geo.py <dir with Natural Earth geojson files>
Needs: ne_50m_admin_0_countries.geojson, ne_10m_land.geojson,
       ne_10m_populated_places_simple.geojson

Writes packages/layout_spec/geo/{world.json,islands.json,places.json} and copies
them to apps/mobile/assets/geo/ (Flutter can only bundle files inside the app).
Coordinates are [lng, lat] pairs flattened into one list per ring.
"""

import json
import math
import shutil
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "packages" / "layout_spec" / "geo"
APP = ROOT / "apps" / "mobile" / "assets" / "geo"

# Islands and small regions that need 1:10m detail (bbox: minLng, minLat, maxLng, maxLat).
ISLAND_BOXES = {
    "zanzibar": (38.9, -7.6, 40.2, -4.7),
    "mallorca": (2.2, 39.2, 3.6, 40.1),
    "santorini": (25.2, 36.3, 25.5, 36.5),
    "mykonos": (25.2, 37.3, 25.5, 37.6),
    "crete": (23.4, 34.7, 26.4, 35.8),
    "sicily": (12.3, 36.5, 15.7, 38.4),
    "sardinia": (8.0, 38.8, 9.9, 41.3),
    "corsica": (8.5, 41.3, 9.6, 43.1),
    "capri": (14.1, 40.5, 14.3, 40.6),
    "madeira": (-17.3, 32.6, -16.6, 32.9),
    "tenerife": (-17.0, 27.9, -16.1, 28.7),
    "bali": (114.4, -8.9, 115.8, -8.0),
    "mauritius": (57.2, -20.6, 57.9, -19.9),
    "iceland": (-24.6, 63.2, -13.4, 66.6),
    "malta": (14.1, 35.7, 14.6, 36.1),
    "hvar": (16.3, 43.0, 17.3, 43.3),
    "phuket": (98.2, 7.7, 98.5, 8.2),
}

ISLAND_NAMES = {
    "zanzibar": {"en": "Zanzibar", "es": "Zanzíbar", "fr": "Zanzibar", "it": "Zanzibar", "de": "Sansibar", "mk": "Занзибар"},
    "mallorca": {"en": "Mallorca", "fr": "Majorque", "it": "Maiorca", "mk": "Мајорка"},
    "santorini": {"en": "Santorini", "fr": "Santorin", "mk": "Санторини"},
    "mykonos": {"en": "Mykonos", "mk": "Миконос"},
    "crete": {"en": "Crete", "de": "Kreta", "es": "Creta", "fr": "Crète", "it": "Creta", "mk": "Крит"},
    "sicily": {"en": "Sicily", "de": "Sizilien", "es": "Sicilia", "fr": "Sicile", "it": "Sicilia", "mk": "Сицилија"},
    "sardinia": {"en": "Sardinia", "de": "Sardinien", "es": "Cerdeña", "fr": "Sardaigne", "it": "Sardegna", "mk": "Сардинија"},
    "corsica": {"en": "Corsica", "de": "Korsika", "es": "Córcega", "fr": "Corse", "it": "Corsica", "mk": "Корзика"},
    "capri": {"en": "Capri", "mk": "Капри"},
    "madeira": {"en": "Madeira", "fr": "Madère", "mk": "Мадеира"},
    "tenerife": {"en": "Tenerife", "fr": "Ténérife", "mk": "Тенерифе"},
    "bali": {"en": "Bali", "mk": "Бали"},
    "mauritius": {"en": "Mauritius", "es": "Mauricio", "fr": "Maurice", "it": "Mauritius", "mk": "Маврициус"},
    "iceland": {"en": "Iceland", "de": "Island", "es": "Islandia", "fr": "Islande", "it": "Islanda", "mk": "Исланд"},
    "malta": {"en": "Malta", "fr": "Malte", "mk": "Малта"},
    "hvar": {"en": "Hvar", "mk": "Хвар"},
    "phuket": {"en": "Phuket", "mk": "Пукет"},
}

# Curated destinations: (key, lng, lat, iso2, {lang: name}); English is required.
CURATED = [
    ("stone_town", 39.1921, -6.1622, "TZ", {"en": "Stone Town", "mk": "Стоун Таун"}),
    ("nungwi", 39.2988, -5.7264, "TZ", {"en": "Nungwi", "mk": "Нунгви"}),
    ("jozani", 39.4169, -6.2656, "TZ", {"en": "Jozani Forest", "de": "Jozani-Wald", "es": "Bosque de Jozani", "fr": "Forêt de Jozani", "it": "Foresta di Jozani", "mk": "Шумата Јозани"}),
    ("paje", 39.5333, -6.2667, "TZ", {"en": "Paje", "mk": "Паје"}),
    ("ohrid", 20.8016, 41.1172, "MK", {"en": "Ohrid", "mk": "Охрид"}),
    ("skopje", 21.4314, 41.9981, "MK", {"en": "Skopje", "mk": "Скопје"}),
    ("bitola", 21.3343, 41.0297, "MK", {"en": "Bitola", "mk": "Битола"}),
    ("struga", 20.6783, 41.1778, "MK", {"en": "Struga", "mk": "Струга"}),
    ("paris", 2.3522, 48.8566, "FR", {"en": "Paris", "mk": "Париз"}),
    ("rome", 12.4964, 41.9028, "IT", {"en": "Rome", "de": "Rom", "es": "Roma", "fr": "Rome", "it": "Roma", "mk": "Рим"}),
    ("barcelona", 2.1734, 41.3851, "ES", {"en": "Barcelona", "fr": "Barcelone", "mk": "Барселона"}),
    ("florence", 11.2558, 43.7696, "IT", {"en": "Florence", "de": "Florenz", "es": "Florencia", "fr": "Florence", "it": "Firenze", "mk": "Фиренца"}),
    ("venice", 12.3155, 45.4408, "IT", {"en": "Venice", "de": "Venedig", "es": "Venecia", "fr": "Venise", "it": "Venezia", "mk": "Венеција"}),
    ("milan", 9.19, 45.4642, "IT", {"en": "Milan", "de": "Mailand", "es": "Milán", "fr": "Milan", "it": "Milano", "mk": "Милано"}),
    ("amalfi", 14.602, 40.634, "IT", {"en": "Amalfi", "mk": "Амалфи"}),
    ("oia", 25.3753, 36.4618, "GR", {"en": "Santorini", "fr": "Santorin", "mk": "Санторини"}),
    ("mykonos", 25.3289, 37.4467, "GR", {"en": "Mykonos", "mk": "Миконос"}),
    ("chania", 24.018, 35.5138, "GR", {"en": "Chania", "fr": "La Canée", "mk": "Ханја"}),
    ("athens", 23.7275, 37.9838, "GR", {"en": "Athens", "de": "Athen", "es": "Atenas", "fr": "Athènes", "it": "Atene", "mk": "Атина"}),
    ("thessaloniki", 22.9444, 40.6401, "GR", {"en": "Thessaloniki", "es": "Tesalónica", "fr": "Thessalonique", "it": "Salonicco", "mk": "Солун"}),
    ("dubrovnik", 18.0944, 42.6507, "HR", {"en": "Dubrovnik", "mk": "Дубровник"}),
    ("split", 16.4402, 43.5081, "HR", {"en": "Split", "mk": "Сплит"}),
    ("kotor", 18.7712, 42.4247, "ME", {"en": "Kotor", "mk": "Котор"}),
    ("lisbon", -9.1393, 38.7223, "PT", {"en": "Lisbon", "de": "Lissabon", "es": "Lisboa", "fr": "Lisbonne", "it": "Lisbona", "mk": "Лисабон"}),
    ("porto", -8.6291, 41.1579, "PT", {"en": "Porto", "es": "Oporto", "mk": "Порто"}),
    ("madrid", -3.7038, 40.4168, "ES", {"en": "Madrid", "mk": "Мадрид"}),
    ("seville", -5.9845, 37.3891, "ES", {"en": "Seville", "de": "Sevilla", "es": "Sevilla", "fr": "Séville", "it": "Siviglia", "mk": "Севиља"}),
    ("granada", -3.5986, 37.1773, "ES", {"en": "Granada", "fr": "Grenade", "mk": "Гранада"}),
    ("palma", 2.6502, 39.5696, "ES", {"en": "Palma", "mk": "Палма"}),
    ("nice", 7.262, 43.7102, "FR", {"en": "Nice", "de": "Nizza", "es": "Niza", "it": "Nizza", "mk": "Ница"}),
    ("lyon", 4.8357, 45.764, "FR", {"en": "Lyon", "es": "Lyon", "it": "Lione", "mk": "Лион"}),
    ("chamonix", 6.8694, 45.9237, "FR", {"en": "Chamonix", "mk": "Шамони"}),
    ("berlin", 13.405, 52.52, "DE", {"en": "Berlin", "es": "Berlín", "it": "Berlino", "mk": "Берлин"}),
    ("munich", 11.582, 48.1351, "DE", {"en": "Munich", "de": "München", "es": "Múnich", "fr": "Munich", "it": "Monaco di Baviera", "mk": "Минхен"}),
    ("vienna", 16.3738, 48.2082, "AT", {"en": "Vienna", "de": "Wien", "es": "Viena", "fr": "Vienne", "it": "Vienna", "mk": "Виена"}),
    ("hallstatt", 13.6493, 47.5622, "AT", {"en": "Hallstatt", "mk": "Халштат"}),
    ("zermatt", 7.7491, 46.0207, "CH", {"en": "Zermatt", "mk": "Цермат"}),
    ("zurich", 8.5417, 47.3769, "CH", {"en": "Zurich", "de": "Zürich", "es": "Zúrich", "fr": "Zurich", "it": "Zurigo", "mk": "Цирих"}),
    ("bled", 14.1146, 46.3683, "SI", {"en": "Lake Bled", "de": "Bleder See", "es": "Lago Bled", "fr": "Lac de Bled", "it": "Lago di Bled", "mk": "Бледско Езеро"}),
    ("prague", 14.4378, 50.0755, "CZ", {"en": "Prague", "de": "Prag", "es": "Praga", "fr": "Prague", "it": "Praga", "mk": "Прага"}),
    ("budapest", 19.0402, 47.4979, "HU", {"en": "Budapest", "mk": "Будимпешта"}),
    ("amsterdam", 4.9041, 52.3676, "NL", {"en": "Amsterdam", "es": "Ámsterdam", "mk": "Амстердам"}),
    ("london", -0.1276, 51.5072, "GB", {"en": "London", "es": "Londres", "fr": "Londres", "it": "Londra", "mk": "Лондон"}),
    ("edinburgh", -3.1883, 55.9533, "GB", {"en": "Edinburgh", "es": "Edimburgo", "fr": "Édimbourg", "it": "Edimburgo", "mk": "Единбург"}),
    ("reykjavik", -21.9426, 64.1466, "IS", {"en": "Reykjavík", "mk": "Рејкјавик"}),
    ("istanbul", 28.9784, 41.0082, "TR", {"en": "Istanbul", "es": "Estambul", "it": "Istanbul", "mk": "Истанбул"}),
    ("goreme", 34.8289, 38.6431, "TR", {"en": "Cappadocia", "de": "Kappadokien", "es": "Capadocia", "it": "Cappadocia", "mk": "Кападокија"}),
    ("sarajevo", 18.4131, 43.8563, "BA", {"en": "Sarajevo", "mk": "Сараево"}),
    ("belgrade", 20.4489, 44.7866, "RS", {"en": "Belgrade", "de": "Belgrad", "es": "Belgrado", "fr": "Belgrade", "it": "Belgrado", "mk": "Белград"}),
    ("sofia", 23.3219, 42.6977, "BG", {"en": "Sofia", "es": "Sofía", "mk": "Софија"}),
    ("tirana", 19.8187, 41.3275, "AL", {"en": "Tirana", "mk": "Тирана"}),
    ("marrakech", -7.9811, 31.6295, "MA", {"en": "Marrakech", "de": "Marrakesch", "es": "Marrakech", "it": "Marrakech", "mk": "Маракеш"}),
    ("cairo", 31.2357, 30.0444, "EG", {"en": "Cairo", "de": "Kairo", "es": "El Cairo", "fr": "Le Caire", "it": "Il Cairo", "mk": "Каиро"}),
    ("cape_town", 18.4241, -33.9249, "ZA", {"en": "Cape Town", "de": "Kapstadt", "es": "Ciudad del Cabo", "fr": "Le Cap", "it": "Città del Capo", "mk": "Кејптаун"}),
    ("nairobi", 36.8219, -1.2921, "KE", {"en": "Nairobi", "mk": "Најроби"}),
    ("arusha", 36.683, -3.3869, "TZ", {"en": "Arusha", "mk": "Аруша"}),
    ("serengeti", 34.8333, -2.3333, "TZ", {"en": "Serengeti", "mk": "Серенгети"}),
    ("new_york", -74.006, 40.7128, "US", {"en": "New York", "es": "Nueva York", "mk": "Њујорк"}),
    ("san_francisco", -122.4194, 37.7749, "US", {"en": "San Francisco", "mk": "Сан Франциско"}),
    ("los_angeles", -118.2437, 34.0522, "US", {"en": "Los Angeles", "es": "Los Ángeles", "mk": "Лос Анџелес"}),
    ("mexico_city", -99.1332, 19.4326, "MX", {"en": "Mexico City", "de": "Mexiko-Stadt", "es": "Ciudad de México", "fr": "Mexico", "it": "Città del Messico", "mk": "Мексико Сити"}),
    ("tulum", -87.4654, 20.2114, "MX", {"en": "Tulum", "mk": "Тулум"}),
    ("havana", -82.3666, 23.1136, "CU", {"en": "Havana", "de": "Havanna", "es": "La Habana", "fr": "La Havane", "it": "L'Avana", "mk": "Хавана"}),
    ("rio", -43.1729, -22.9068, "BR", {"en": "Rio de Janeiro", "mk": "Рио де Жанеиро"}),
    ("buenos_aires", -58.3816, -34.6037, "AR", {"en": "Buenos Aires", "mk": "Буенос Аирес"}),
    ("cusco", -71.9675, -13.532, "PE", {"en": "Cusco", "es": "Cuzco", "mk": "Куско"}),
    ("tokyo", 139.6503, 35.6762, "JP", {"en": "Tokyo", "es": "Tokio", "mk": "Токио"}),
    ("kyoto", 135.7681, 35.0116, "JP", {"en": "Kyoto", "es": "Kioto", "mk": "Кјото"}),
    ("seoul", 126.978, 37.5665, "KR", {"en": "Seoul", "es": "Seúl", "fr": "Séoul", "mk": "Сеул"}),
    ("bangkok", 100.5018, 13.7563, "TH", {"en": "Bangkok", "mk": "Бангкок"}),
    ("chiang_mai", 98.9853, 18.7883, "TH", {"en": "Chiang Mai", "mk": "Чијанг Мај"}),
    ("phuket", 98.3923, 7.8804, "TH", {"en": "Phuket", "mk": "Пукет"}),
    ("ubud", 115.2625, -8.5069, "ID", {"en": "Ubud", "mk": "Убуд"}),
    ("singapore", 103.8198, 1.3521, "SG", {"en": "Singapore", "de": "Singapur", "es": "Singapur", "fr": "Singapour", "it": "Singapore", "mk": "Сингапур"}),
    ("sydney", 151.2093, -33.8688, "AU", {"en": "Sydney", "es": "Sídney", "mk": "Сиднеј"}),
    ("queenstown", 168.6626, -45.0312, "NZ", {"en": "Queenstown", "mk": "Квинстаун"}),
    ("dubai", 55.2708, 25.2048, "AE", {"en": "Dubai", "es": "Dubái", "fr": "Dubaï", "mk": "Дубаи"}),
    ("valletta", 14.5146, 35.8989, "MT", {"en": "Valletta", "es": "La Valeta", "fr": "La Valette", "mk": "Валета"}),
    ("funchal", -16.9241, 32.6669, "PT", {"en": "Funchal", "mk": "Фуншал"}),
    ("port_louis", 57.5012, -20.1609, "MU", {"en": "Port Louis", "mk": "Порт Луј"}),
]

LATIN_TO_MK = [
    ("sch", "ш"), ("sh", "ш"), ("ch", "ч"), ("zh", "ж"), ("dj", "џ"), ("dzh", "џ"),
    ("lj", "љ"), ("nj", "њ"), ("ts", "ц"), ("ya", "ја"), ("yu", "ју"), ("yo", "јо"),
    ("ph", "ф"), ("th", "т"), ("kh", "х"), ("ck", "к"), ("oo", "у"), ("ee", "и"),
    ("a", "а"), ("b", "б"), ("c", "к"), ("d", "д"), ("e", "е"), ("f", "ф"), ("g", "г"),
    ("h", "х"), ("i", "и"), ("j", "ј"), ("k", "к"), ("l", "л"), ("m", "м"), ("n", "н"),
    ("o", "о"), ("p", "п"), ("q", "к"), ("r", "р"), ("s", "с"), ("t", "т"), ("u", "у"),
    ("v", "в"), ("w", "в"), ("x", "кс"), ("y", "ј"), ("z", "з"),
]


def to_mk(name: str) -> str:
    """Rough Latin → Macedonian Cyrillic transliteration for place names
    that have no curated Macedonian name."""
    out, i, low = "", 0, name.lower()
    while i < len(name):
        for lat, cyr in LATIN_TO_MK:
            if low.startswith(lat, i):
                out += cyr.upper()[0] + cyr[1:] if name[i].isupper() else cyr
                i += len(lat)
                break
        else:
            out += name[i]
            i += 1
    return out


def perp_dist(p, a, b):
    if a == b:
        return math.dist(p, a)
    (x, y), (x1, y1), (x2, y2) = p, a, b
    return abs((y2 - y1) * x - (x2 - x1) * y + x2 * y1 - y2 * x1) / math.dist(a, b)


def simplify(points, tol):
    if len(points) < 4:
        return points
    keep = [False] * len(points)
    keep[0] = keep[-1] = True
    stack = [(0, len(points) - 1)]
    while stack:
        s, e = stack.pop()
        best, idx = 0.0, -1
        for i in range(s + 1, e):
            d = perp_dist(points[i], points[s], points[e])
            if d > best:
                best, idx = d, i
        if best > tol and idx > 0:
            keep[idx] = True
            stack += [(s, idx), (idx, e)]
    return [p for p, k in zip(points, keep) if k]


def flat(ring, decimals):
    out = []
    for lng, lat in ring:
        out += [round(lng, decimals), round(lat, decimals)]
    return out


def polys_of(geom):
    if geom["type"] == "Polygon":
        return [geom["coordinates"]]
    return geom["coordinates"]


def build(src: Path) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    countries = json.loads((src / "ne_50m_admin_0_countries.geojson").read_text(encoding="utf-8"))
    world = []
    for f in countries["features"]:
        p = f["properties"]
        iso = p["ISO_A2_EH"] if p["ISO_A2"] == "-99" else p["ISO_A2"]
        rings = []
        for poly in polys_of(f["geometry"]):
            ring = simplify(poly[0], 0.03)
            if len(ring) >= 4:
                rings.append(flat(ring, 2))
        world.append({"iso": iso, "name": p["NAME"], "rings": rings})
    (OUT / "world.json").write_text(json.dumps({"source": "Natural Earth 1:50m", "countries": world}, separators=(",", ":")), encoding="utf-8")

    land = json.loads((src / "ne_10m_land.geojson").read_text(encoding="utf-8"))
    islands = []
    for key, (x0, y0, x1, y1) in ISLAND_BOXES.items():
        rings = []
        for f in land["features"]:
            for poly in polys_of(f["geometry"]):
                ring = poly[0]
                xs = [c[0] for c in ring]
                ys = [c[1] for c in ring]
                cx, cy = (min(xs) + max(xs)) / 2, (min(ys) + max(ys)) / 2
                # Only whole islands whose centre lies in the box and that are
                # not continent-sized.
                if x0 <= cx <= x1 and y0 <= cy <= y1 and (max(xs) - min(xs)) < (x1 - x0) * 1.5:
                    s = simplify(ring, 0.004)
                    if len(s) >= 4:
                        rings.append(flat(s, 4))
        islands.append({"key": key, "names": ISLAND_NAMES[key], "bbox": [x0, y0, x1, y1], "rings": rings})
    (OUT / "islands.json").write_text(json.dumps({"source": "Natural Earth 1:10m land", "islands": islands}, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")

    places = []
    for key, lng, lat, iso, names in CURATED:
        names = dict(names)
        names.setdefault("mk", to_mk(names["en"]))
        places.append({"id": key, "lng": lng, "lat": lat, "country": iso, "names": names})
    have = {p["names"]["en"].lower() for p in places}
    pp = json.loads((src / "ne_10m_populated_places_simple.geojson").read_text(encoding="utf-8"))
    cities = sorted(
        (f["properties"] for f in pp["features"]),
        key=lambda p: (-(p["adm0cap"] or 0), -(p["pop_max"] or 0)),
    )
    for c in cities:
        if len(places) >= 200:
            break
        if c["name"].lower() in have or c["iso_a2"] in ("-99", None):
            continue
        have.add(c["name"].lower())
        places.append({
            "id": c["nameascii"].lower().replace(" ", "_"),
            "lng": round(c["longitude"], 4),
            "lat": round(c["latitude"], 4),
            "country": c["iso_a2"],
            "names": {"en": c["name"], "mk": to_mk(c["nameascii"])},
        })
    (OUT / "places.json").write_text(json.dumps({"source": "Natural Earth populated places + curated", "places": places}, ensure_ascii=False, indent=1), encoding="utf-8")

    APP.mkdir(parents=True, exist_ok=True)
    for name in ("world.json", "islands.json", "places.json"):
        shutil.copy(OUT / name, APP / name)
    for name in ("world.json", "islands.json", "places.json"):
        print(name, (OUT / name).stat().st_size, "bytes")
    print("places:", len(places), "islands:", {i["key"]: len(i["rings"]) for i in islands})


if __name__ == "__main__":
    build(Path(sys.argv[1]))
