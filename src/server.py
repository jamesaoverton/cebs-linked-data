import csv
import io
import requests

from flask import Flask, send_file, request
from openpyxl import Workbook

app = Flask(__name__)

@app.route('/')
def index():
    return send_file("index.html")

@app.route('/demo.js')
def demo_js():
    return send_file("demo.js")

@app.route('/demo.css')
def demo_css():
    return send_file("demo.css")

@app.route('/assay.json')
def assay_json():
    return send_file("../build/www/assay.json")

@app.route('/tree.html')
def tree():
    return send_file("../build/cebs.html")

@app.route('/cebs.owl')
def cebs_owl():
    return send_file("../build/cebs.owl")

def query_cebsr(query):
    return requests.get("https://manticore.niehs.nih.gov/cebsr-api?query=" + request.args["query"])

def json2nodes(json):
    return json["data"]["studyTestDataDomainView"]["edges"]

def nodes2rows(nodes):
    rows = []
    for node in nodes:
        row = {
            "STUDY_TITLE": node["node"]["studyUid"]["studyTitle"],
            "TEST_NAME": node["node"]["testName"],
            "DATA_DOMAIN": node["node"]["dataDomain"]
        }
        for item in node["node"]["studyUid"]["VStudyMetadataStudy"]["edges"]:
            row[item["node"]["attrName"]] = item["node"]["attrValue"]
        rows.append(row)
    return rows

fieldnames = [
    "STUDY_TITLE",
    "TEST_NAME",
    "DATA_DOMAIN",
    "ABSTRACT_URL",
    "CEBS_URL",
    "CHEMTRACK_NUMBER",
    "CITATION",
    "DATA_SOURCE",
    "DOI_URL",
    "DURATION",
    "INSTITUTION",
    "LABORATORY",
    "PRINCIPAL_INVESTIGATOR",
    "PUBLICATION_ID",
    "PUBLICATION_NUMBER",
    "PWG_APPROVAL_DATE",
    "START_DATE",
    "STUDY_AREA",
    "STUDY_DESIGN",
    "STUDY_TYPE",
    "STUDY_VARIABLES",
    "SUBJECT_TYPE",
    "TDMSE_LOCK_DATE",
    "TDMS_NUMBER",
    "TECH_REPORT_URL",
]

def rows2tsv(rows):
    output = io.StringIO()
    w = csv.DictWriter(output, fieldnames, delimiter="\t", lineterminator="\n", extrasaction="ignore")
    w.writeheader()
    w.writerows(rows)
    return output.getvalue()

def rows2csv(rows):
    output = io.StringIO()
    w = csv.DictWriter(output, fieldnames, extrasaction="ignore")
    w.writeheader()
    w.writerows(rows)
    return output.getvalue()

def rows2xlsx(rows):
    wb = Workbook()
    ws = wb.active
    ws.append(fieldnames)
    for row in rows:
        ws.append([row.get(f) for f in fieldnames])
    output = io.BytesIO()
    wb.save(output)
    wb.close()
    output.seek(0)
    return output

@app.route('/query.json')
def query_json():
    result = query_cebsr(request.args["query"])
    return {
        "pageInfo": result.json()["data"]["studyTestDataDomainView"]["pageInfo"],
        "data": nodes2rows(json2nodes(result.json())),
    }

@app.route('/query.tsv')
def query_tsv():
    result = query_cebsr(request.args["query"])
    return rows2tsv(nodes2rows(json2nodes(result.json()))), 200, {"Content-Type": "text/tsv"}

@app.route('/query.csv')
def query_csv():
    result = query_cebsr(request.args["query"])
    return rows2csv(nodes2rows(json2nodes(result.json()))), 200, {"Content-Type": "text/csv"}

@app.route('/query.xlsx')
def query_xlsx():
    result = query_cebsr(request.args["query"])
    return send_file(
        rows2xlsx(nodes2rows(json2nodes(result.json()))),
        as_attachment=True,
        attachment_filename="query.xlsx",
        mimetype="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    )
