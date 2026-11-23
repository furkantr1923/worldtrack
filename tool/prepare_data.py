#!/usr/bin/env python3
"""WORLDTRACK veri hazırlama aracı.

Uygulamanın içine gömülen coğrafi verileri açık kaynaklardan üretir:

  * Natural Earth 1:50m Admin-0 ülke sınırları (kamu malı)
      -> assets/data/world_shapes.json   (sadeleştirilmiş poligonlar)
  * GeoNames countryInfo + cities15000 + admin1 + alternateNamesV2 (CC BY 4.0)
      -> assets/data/countries.json      (ülke meta verisi, Türkçe adlar)
      -> assets/data/cities.tsv.gz       (nüfusu 15.000+ olan şehirler)

Kullanım:
    python3 tool/prepare_data.py --out assets/data [--ne yerel.geojson] [--cache .cache]

Hiçbir bilgi uydurulmaz: bir alan kaynakta yoksa boş bırakılır.
"""
from __future__ import annotations

import argparse
import gzip
import io
import json
import os
import sys
import urllib.request
import zipfile
from collections import defaultdict

NE_BASE = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/"
NE_URL = NE_BASE + "ne_50m_admin_0_countries.geojson"
# Şehirleri KKTC / Somaliland'e atarken hassas (1:10m) sınırlar kullanılır.
NE_DETAIL_URL = NE_BASE + "ne_10m_admin_0_countries.geojson"
DETAIL_NAMES = {"N. Cyprus": "XC", "Cyprus": "CY", "Somaliland": "XS", "Somalia": "SO",
                "Cyprus U.N. Buffer Zone": "CY"}
GN = "https://download.geonames.org/export/dump/"

# Natural Earth'te ISO kodu olmayan (-99) varlıklar için uygulama içi kodlar.
SPECIAL_CODES = {
    "N. Cyprus": "XC",      # Kuzey Kıbrıs Türk Cumhuriyeti
    "Somaliland": "XS",
}
# Özel varlıkların başkentleri (GeoNames geonameid). Lefkoşa bölünmüş bir şehirdir;
# GeoNames kaydı Kıbrıs Cumhuriyeti'nde kalır, KKTC'nin başkenti olarak da gösterilir.
SPECIAL_CAPITALS = {"XC": 146268, "XS": 57289}
SKIP_NAMES = {"Siachen Glacier"}
# GeoNames'te tarihî olarak duran, artık var olmayan ülkeler.
DISSOLVED = {"AN", "CS"}             # Şehri olmayan, tartışmalı buzul
MERGE_INTO = {"Indian Ocean Ter.": "AU", "Ashmore and Cartier Is.": "AU"}

REGION_TR = {
    "Africa": "Afrika", "Americas": "Amerika", "Asia": "Asya", "Europe": "Avrupa",
    "Oceania": "Okyanusya", "Antarctica": "Antarktika",
    "Seven seas (open ocean)": "Açık deniz",
}
SUBREGION_TR = {
    "Eastern Africa": "Doğu Afrika", "Middle Africa": "Orta Afrika",
    "Northern Africa": "Kuzey Afrika", "Southern Africa": "Güney Afrika",
    "Western Africa": "Batı Afrika", "Caribbean": "Karayipler",
    "Central America": "Orta Amerika", "South America": "Güney Amerika",
    "Northern America": "Kuzey Amerika", "Central Asia": "Orta Asya",
    "Eastern Asia": "Doğu Asya", "South-Eastern Asia": "Güneydoğu Asya",
    "Southern Asia": "Güney Asya", "Western Asia": "Batı Asya",
    "Eastern Europe": "Doğu Avrupa", "Northern Europe": "Kuzey Avrupa",
    "Southern Europe": "Güney Avrupa", "Western Europe": "Batı Avrupa",
    "Australia and New Zealand": "Avustralya ve Yeni Zelanda",
    "Melanesia": "Melanezya", "Micronesia": "Mikronezya", "Polynesia": "Polinezya",
    "Antarctica": "Antarktika", "Seven seas (open ocean)": "Açık deniz",
}
CONTINENT_TR = {
    "AF": "Afrika", "AS": "Asya", "EU": "Avrupa", "NA": "Kuzey Amerika",
    "OC": "Okyanusya", "SA": "Güney Amerika", "AN": "Antarktika",
}
TYPE_TR = {
    "Sovereign country": "Egemen ülke", "Country": "Egemen ülke",
    "Sovereignty": "Egemen ülke", "Dependency": "Bağımlı bölge",
    "Disputed": "Tartışmalı bölge", "Indeterminate": "Statüsü belirsiz bölge",
}

SCALE = 100  # koordinatlar 0,01° hassasiyetle (yaklaşık 1 km) saklanır


def fetch(url: str, cache: str) -> bytes:
    os.makedirs(cache, exist_ok=True)
    path = os.path.join(cache, url.rsplit("/", 1)[-1])
    if not os.path.exists(path):
        print(f"indiriliyor: {url}", file=sys.stderr)
        req = urllib.request.Request(url, headers={"User-Agent": "WORLDTRACK-data-tool/1.0"})
        with urllib.request.urlopen(req, timeout=300) as r, open(path + ".part", "wb") as f:
            while True:
                chunk = r.read(1 << 20)
                if not chunk:
                    break
                f.write(chunk)
        os.replace(path + ".part", path)
    with open(path, "rb") as f:
        return f.read()


def zip_member(data: bytes, name: str) -> io.TextIOWrapper:
    z = zipfile.ZipFile(io.BytesIO(data))
    return io.TextIOWrapper(z.open(name), encoding="utf-8")


# ---------------------------------------------------------------- geometri
def ring_to_ints(ring):
    out, last = [], None
    for lon, lat in ring:
        p = (round(lon * SCALE), round(lat * SCALE))
        if p != last:
            out.extend(p)
            last = p
    if len(out) >= 4 and out[:2] == out[-2:]:
        out = out[:-2]  # kapanış noktası uygulamada tekrar eklenmez
    return out if len(out) >= 6 else None


def point_in_shape(x, y, polys, scale=SCALE):
    for poly in polys:
        if _pir(x, y, poly[0], scale) and not any(_pir(x, y, h, scale) for h in poly[1:]):
            return True
    return False


def _pir(x, y, ring, scale):
    inside = False
    n = len(ring) // 2
    j = n - 1
    for i in range(n):
        xi, yi = ring[2 * i] / scale, ring[2 * i + 1] / scale
        xj, yj = ring[2 * j] / scale, ring[2 * j + 1] / scale
        if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi:
            inside = not inside
        j = i
    return inside


DETAIL_SCALE = 100000


def load_detail_shapes(path, cache):
    raw = open(path, "rb").read() if path else fetch(NE_DETAIL_URL, cache)
    out = defaultdict(list)
    for f in json.loads(raw)["features"]:
        code = DETAIL_NAMES.get(f["properties"]["NAME"])
        if not code:
            continue
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for poly in polys:
            out[code].append([[round(v * DETAIL_SCALE) for pt in r for v in pt] for r in poly])
    return out


def nearest_dist(x, y, polys, scale):
    best = float("inf")
    for poly in polys:
        r = poly[0]
        for i in range(0, len(r), 2):
            d = (r[i] / scale - x) ** 2 + (r[i + 1] / scale - y) ** 2
            best = min(best, d)
    return best


def assign_special(cities, detail):
    """KKTC ve Somaliland sınırları içindeki şehirleri o varlığa bağlar.

    Başkent (PPLC) kayıtları ana ülkede bırakılır (Lefkoşa bölünmüş bir şehirdir).
    Kıyıdaki şehirler poligon dışında kalabilir; o durumda en yakın sınır seçilir.
    """
    for c in cities:
        for special, parent in (("XC", "CY"), ("XS", "SO")):
            if c["cc"] not in (parent, special) or c["code"] == "PPLC":
                continue
            x, y = c["lon"], c["lat"]
            if point_in_shape(x, y, detail[special], DETAIL_SCALE):
                c["cc"] = special
            elif point_in_shape(x, y, detail[parent], DETAIL_SCALE):
                c["cc"] = parent
            else:
                near_s = nearest_dist(x, y, detail[special], DETAIL_SCALE)
                near_p = nearest_dist(x, y, detail[parent], DETAIL_SCALE)
                c["cc"] = special if near_s < near_p else parent


def load_ne(path: str | None, cache: str):
    raw = open(path, "rb").read() if path else fetch(NE_URL, cache)
    feats = json.loads(raw)["features"]
    shapes, meta = {}, {}
    for f in feats:
        p = f["properties"]
        name = p["NAME"]
        if name in SKIP_NAMES:
            continue
        code = MERGE_INTO.get(name) or SPECIAL_CODES.get(name) or p["ISO_A2_EH"]
        if code in ("-99", "", None):
            print(f"uyarı: kodsuz varlık atlandı: {name}", file=sys.stderr)
            continue
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        out = []
        for poly in polys:
            rings = [r for r in (ring_to_ints(r) for r in poly) if r]
            if rings:
                out.append(rings)
        shapes.setdefault(code, []).extend(out)
        if name in MERGE_INTO:
            continue
        meta[code] = {
            "nameTr": p.get("NAME_TR") or "",
            "nameEn": p.get("NAME_EN") or p.get("NAME") or "",
            "iso3": p.get("ISO_A3_EH") if p.get("ISO_A3_EH") not in ("-99", None) else "",
            "region": REGION_TR.get(p.get("REGION_UN"), ""),
            "subregion": SUBREGION_TR.get(p.get("SUBREGION"), ""),
            "type": TYPE_TR.get(p.get("TYPE"), ""),
            "labelLon": round(p["LABEL_X"], 3),
            "labelLat": round(p["LABEL_Y"], 3),
            "minLabel": p.get("MIN_LABEL"),
            "wikidata": p.get("WIKIDATAID") or "",
        }
    return shapes, meta


# ---------------------------------------------------------------- GeoNames
def load_geonames(cache: str):
    info = {}
    for line in fetch(GN + "countryInfo.txt", cache).decode("utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        c = line.split("\t")
        info[c[0]] = {
            "iso3": c[1], "name": c[4], "capital": c[5],
            "area": float(c[6]) if c[6] else None,
            "population": int(c[7]) if c[7] else None,
            "continent": c[8], "currency": c[10], "currencyName": c[11],
            "geonameid": int(c[16]) if c[16] else None,
        }
    admin1 = {}
    for line in fetch(GN + "admin1CodesASCII.txt", cache).decode("utf-8").splitlines():
        c = line.split("\t")
        if len(c) >= 4:
            admin1[c[0]] = (c[1], int(c[3]))
    cities = []
    with zip_member(fetch(GN + "cities15000.zip", cache), "cities15000.txt") as f:
        for line in f:
            c = line.rstrip("\n").split("\t")
            # Yalnızca gerçek yerleşimler: semt/bölüm (PPLX), tarihî (PPLH),
            # terk edilmiş (PPLQ) ve yıkılmış (PPLW) kayıtlar alınmaz.
            if c[6] != "P" or c[7] in ("PPLX", "PPLH", "PPLQ", "PPLW"):
                continue
            cities.append({
                "id": int(c[0]), "name": c[1], "ascii": c[2],
                "lat": float(c[4]), "lon": float(c[5]), "code": c[7],
                "cc": c[8], "admin1": f"{c[8]}.{c[10]}",
                "pop": int(c[14]) if c[14] else 0,
            })
    return info, admin1, cities


def load_turkish_names(cache: str, wanted: set[int]):
    """alternateNamesV2'den Türkçe (tr) adları seçer."""
    best: dict[int, tuple[int, str]] = {}
    data = fetch(GN + "alternateNamesV2.zip", cache)
    with zip_member(data, "alternateNamesV2.txt") as f:
        for line in f:
            c = line.rstrip("\n").split("\t")
            if len(c) < 8 or c[2] != "tr":
                continue
            gid = int(c[1])
            if gid not in wanted:
                continue
            if c[6] == "1" or c[7] == "1":  # argo veya tarihî ad
                continue
            score = (2 if c[4] == "1" else 0) + (1 if c[5] == "1" else 0)
            if gid not in best or score > best[gid][0]:
                best[gid] = (score, c[3])
    return {k: v[1] for k, v in best.items()}


# ---------------------------------------------------------------- ana akış
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="assets/data")
    ap.add_argument("--ne", default=None)
    ap.add_argument("--ne-detail", default=None)
    ap.add_argument("--cache", default=".cache")
    args = ap.parse_args()

    shapes, ne = load_ne(args.ne, args.cache)
    info, admin1, cities = load_geonames(args.cache)

    wanted = {c["id"] for c in cities}
    wanted |= {v["geonameid"] for v in info.values() if v["geonameid"]}
    wanted |= {v[1] for v in admin1.values()}
    tr = load_turkish_names(args.cache, wanted)

    # Kuzey Kıbrıs ve Somaliland poligonları içindeki şehirleri o varlığa bağla.
    assign_special(cities, load_detail_shapes(args.ne_detail, args.cache))

    codes = sorted((set(ne) | set(info)) - DISSOLVED)
    capitals = {}
    by_id = {c["id"]: c for c in cities}
    for c in cities:
        if c["code"] == "PPLC":
            capitals.setdefault(c["cc"], c)
    for code, gid in SPECIAL_CAPITALS.items():
        if gid in by_id:
            capitals[code] = by_id[gid]

    countries = []
    for code in codes:
        n, g = ne.get(code, {}), info.get(code, {})
        gid = g.get("geonameid")
        name_tr = n.get("nameTr") or (tr.get(gid) if gid else None) or g.get("name") or n.get("nameEn")
        cap = capitals.get(code)
        cap_en = g.get("capital") or (cap["name"] if cap else "")
        if cap and code not in SPECIAL_CAPITALS and cap_en and cap["ascii"].lower() != cap_en.lower() and cap["name"].lower() != cap_en.lower():
            cap = None  # GeoNames başkent adı ile şehir kaydı uyuşmuyorsa kullanma
        cap_tr = (tr.get(cap["id"]) if cap else None) or (cap["name"] if cap else cap_en)
        countries.append({
            "code": code,
            "iso3": n.get("iso3") or g.get("iso3") or "",
            "nameTr": name_tr,
            "nameEn": n.get("nameEn") or g.get("name") or "",
            "region": n.get("region") or CONTINENT_TR.get(g.get("continent", ""), ""),
            "subregion": n.get("subregion", ""),
            "continent": CONTINENT_TR.get(g.get("continent", ""), ""),
            "type": n.get("type", ""),
            "capitalTr": cap_tr or "",
            "capitalEn": cap_en,
            "capitalCityId": cap["id"] if cap else None,
            "population": g.get("population"),
            "areaKm2": g.get("area"),
            "currency": g.get("currency", ""),
            "currencyName": g.get("currencyName", ""),
            "wikidata": n.get("wikidata", ""),
            # Aramada kullanılacak diğer adlar (ör. "Çekya", "Czechia").
            "aliases": sorted({a for a in ((tr.get(gid) if gid else None), g.get("name"))
                               if a and a not in (name_tr, n.get("nameEn"))}),
            "hasShape": code in shapes,
            "labelLon": n.get("labelLon"),
            "labelLat": n.get("labelLat"),
            "minLabel": n.get("minLabel"),
        })

    os.makedirs(args.out, exist_ok=True)
    with open(os.path.join(args.out, "countries.json"), "w", encoding="utf-8") as f:
        json.dump(countries, f, ensure_ascii=False, separators=(",", ":"))
    with open(os.path.join(args.out, "world_shapes.json"), "w", encoding="utf-8") as f:
        json.dump(shapes, f, separators=(",", ":"))

    known = {c["code"] for c in countries}
    rows = []
    for c in sorted(cities, key=lambda c: (-c["pop"], c["id"])):
        if c["cc"] not in known:
            continue
        a1 = admin1.get(c["admin1"])
        a1_name = (tr.get(a1[1]) or a1[0]) if a1 else ""
        name_tr = tr.get(c["id"]) or c["name"]
        rows.append("\t".join(str(x) for x in (
            c["id"], c["cc"], name_tr.replace("\t", " "), c["name"].replace("\t", " "),
            c["ascii"], a1_name.replace("\t", " "), f'{c["lat"]:.4f}', f'{c["lon"]:.4f}',
            c["pop"], 1 if c["code"] == "PPLC" else 0,
        )))
    with gzip.open(os.path.join(args.out, "cities.tsv.gz"), "wt", encoding="utf-8", compresslevel=9) as f:
        f.write("id\tcountry\tname_tr\tname\tascii\tadmin1\tlat\tlon\tpopulation\tcapital\n")
        f.write("\n".join(rows) + "\n")

    print(f"ülke: {len(countries)}  poligonlu: {len(shapes)}  şehir: {len(rows)}  tr-ad: {len(tr)}")


if __name__ == "__main__":
    main()
