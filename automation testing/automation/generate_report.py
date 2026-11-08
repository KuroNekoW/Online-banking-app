"""Convert real pytest --junitxml output into HTML, CSV and Markdown evidence.

Only reads actual test result XML. Never generates fabricated PASS/FAIL data.
Python standard library only.
"""
import csv
from datetime import datetime
from html import escape
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET


def report(junit_file: Path) -> None:
    if not junit_file.is_file():
        raise SystemExit(f"Khong tim thay JUnit XML: {junit_file}")
    root = ET.parse(junit_file).getroot()
    cases = root.findall(".//testcase")
    if not cases:
        raise SystemExit(f"JUnit XML khong co testcase: {junit_file}")
    rows = []
    for tc in cases:
        name = tc.attrib.get("name", "")
        failure = tc.find("failure")
        error = tc.find("error")
        skipped = tc.find("skipped")
        marker = failure if failure is not None else error
        if marker is not None:
            status = "FAILED" if failure is not None else "ERROR"
        elif skipped is not None:
            status = "SKIPPED"
        else:
            status = "PASSED"
        match = re.search(r"tc_([a-z]+)_(\d{2})", name, re.IGNORECASE)
        test_case_id = ("TC_" + match.group(1).upper() + "_" + match.group(2)) if match else "Supplementary / existing"
        detail = ""
        if marker is not None:
            detail = (marker.attrib.get("message", "") or marker.text or "").strip().splitlines()[0][:500]
        rows.append({
            "Test Case ID": test_case_id,
            "Pytest Script": name,
            "Status": status,
            "Duration (s)": tc.attrib.get("time", ""),
            "Details": detail,
        })
    counts = {key: sum(x["Status"] == key for x in rows) for key in ("PASSED", "FAILED", "ERROR", "SKIPPED")}
    executed = counts["PASSED"] + counts["FAILED"] + counts["ERROR"]
    pass_rate = f"{(counts['PASSED'] / executed * 100):.1f}%" if executed else "N/A"
    stem = junit_file.with_suffix("")
    csv_path = stem.with_suffix(".csv")
    html_path = stem.with_suffix(".html")
    md_path = stem.with_suffix(".md")
    with csv_path.open("w", newline="", encoding="utf-8-sig") as f:
        w = csv.DictWriter(f, fieldnames=list(rows[0]))
        w.writeheader()
        w.writerows(rows)

    table_rows = "\n".join(
        "<tr><td>{}</td><td>{}</td><td class=\"{}\">{}</td><td>{}</td><td>{}</td></tr>".format(
            escape(x["Test Case ID"]), escape(x["Pytest Script"]), x["Status"],
            x["Status"], escape(x["Duration (s)"]), escape(x["Details"])
        ) for x in rows
    )
    html = f'''<!doctype html><html lang="vi"><head><meta charset="utf-8" />
<title>SE113 — Automation Test Results</title>
<style>body{{font-family:Arial,sans-serif;max-width:1150px;margin:35px auto;color:#14223b;padding:0 18px}}
header{{border-bottom:4px solid #006fb9;padding-bottom:10px}}h1{{margin-bottom:8px}}.muted{{color:#65748b}}
.stats{{display:flex;gap:14px;flex-wrap:wrap;margin:25px 0}}.stat{{border:1px solid #d4deeb;padding:16px 24px;border-radius:10px;min-width:125px}}
.stat strong{{display:block;font-size:28px;margin-top:7px}}table{{border-collapse:collapse;width:100%}}
th,td{{border:1px solid #d6dfeb;text-align:left;padding:9px;vertical-align:top;word-break:break-word}}th{{background:#e9f2fb}}
.PASSED{{color:#137345;font-weight:bold}}.FAILED,.ERROR{{color:#b12b2b;font-weight:bold}}.SKIPPED{{color:#a66705;font-weight:bold}}
.note{{background:#f4f7fb;padding:14px;border-left:3px solid #7891b0;margin-top:28px}}
@media print{{body{{margin:12px}}.stats{{page-break-inside:avoid}}}}</style></head>
<body><header><div class="muted">SE113 · Mobile Online Banking · Nhóm 5</div><h1>Automation Test Execution Report</h1>
<div class="muted">Nguồn: {escape(junit_file.name)} — Tạo từ file kết quả pytest thực tế</div></header>
<div class="stats"><div class="stat">Total<strong>{len(rows)}</strong></div>
<div class="stat">Passed<strong>{counts['PASSED']}</strong></div><div class="stat">Failed<strong>{counts['FAILED']}</strong></div>
<div class="stat">Error<strong>{counts['ERROR']}</strong></div><div class="stat">Skipped<strong>{counts['SKIPPED']}</strong></div>
<div class="stat">Pass Rate*<strong>{pass_rate}</strong></div></div>
<h2>Danh sách kết quả</h2><table><thead><tr><th>Test Case ID</th><th>Pytest Script</th><th>Status</th><th>Duration (s)</th><th>Detail (nếu lỗi)</th></tr></thead><tbody>{table_rows}</tbody></table>
<div class="note"><b>Phạm vi:</b> Kiểm thử API tự động / Backend integration testing; không phải kiểm thử giao diện Flutter. 
Dữ liệu thực thi trên PostgreSQL kiểm thử riêng. *Pass Rate = Passed/(Passed+Failed+Error); không đồng nghĩa với code coverage.</div>
</body></html>'''
    html_path.write_text(html, encoding="utf-8")
    md_rows = ["| Test Case | Script | Status |", "|---|---|---|"]
    md_rows.extend(
        f'| {x["Test Case ID"]} | `{x["Pytest Script"]}` | {x["Status"]} |'
        for x in rows
    )
    markdown = (
        "## Kết quả kiểm thử tự động API — Nhóm 5\n\n"
        f"**Nguồn bằng chứng:** `{junit_file.name}` do pytest xuất từ lần chạy thực tế.\n\n"
        f"**Tổng số:** {len(rows)}; **Passed:** {counts['PASSED']}; **Failed:** {counts['FAILED']}; "
        f"**Error:** {counts['ERROR']}; **Skipped:** {counts['SKIPPED']}; **Pass Rate:** {pass_rate}.\n\n"
        "**Môi trường:** FastAPI + pytest + HTTPX/FastAPI TestClient + PostgreSQL (database `banking_test` riêng). "
        "OTP sử dụng fixture giả lập, không gửi email thật.\n\n"
        "**Loại kiểm thử:** API Automation Testing / Backend Integration Testing; không phải UI Automation.\n\n"
        + "\n".join(md_rows) + "\n\n"
        "**Đánh giá:** Các test FAILED/ERROR (nếu có) cần được phân tích, đối chiếu SRS và ghi vào Defect Summary. "
        "Tỷ lệ Passed không đồng nghĩa với Code Coverage. "
        "Không suy ra hệ thống không còn lỗi khi tất cả test đều Passed.\n"
    )
    md_path.write_text(markdown, encoding="utf-8")
    print("BAO CAO DUOC TAO TU XML THAT:")
    print("  XML: ", junit_file)
    print("  HTML:", html_path)
    print("  CSV: ", csv_path)
    print("  MD:  ", md_path)
    print(f"  Total={len(rows)} Passed={counts['PASSED']} Failed={counts['FAILED']} Error={counts['ERROR']} Skipped={counts['SKIPPED']} Rate={pass_rate}")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("Usage: python generate_report.py <pytest_junit.xml>")
    report(Path(sys.argv[1]))
