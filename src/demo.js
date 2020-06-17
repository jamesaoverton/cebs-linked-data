var endpoint = "https://cebs.ontodev.com/"
var graphiql = "https://manticore.niehs.nih.gov/cebsr-api#operationName=endpoint_search&query="
var limit = 10;

// ## Utility Functions

function format(string, args) {
  return string.replace(/\{(\d+)\}/g, function (m, n) { return args[n]; });
}

var padding = '                         '; // 25
function pad(str) {
  return (str + padding).substring(0, Math.max(str.length, padding.length));
};

function invert(obj) {
  var new_obj = {};
  for (var prop in obj) {
    if(obj.hasOwnProperty(prop)) {
      new_obj[obj[prop]] = prop;
    }
  }
  return new_obj;
};

function tree2labels(tree) {
  var labels = [];
  for (var i=0; i < tree.length; i++) {
    var node = tree[i];
    labels.push(node.text);
    if (node.children) {
      labels = labels.concat(tree2labels(node.children));
    }
  }
  return labels;
}

function tree2map(tree) {
  var labels = {};
  for (var i=0; i < tree.length; i++) {
    var node = tree[i];
    var iri = node.iri.replace('http://purl.obolibrary.org/obo/', 'obo:')
      .replace('http://iedb.org/taxon/', 'taxon:');
    labels[node.text] = iri;
    if (node.children) {
      labels = Object.assign(labels, tree2map(node.children));
    }
  }
  return labels;
}


// ## Initialization

var query_editor = ace.edit("query_editor");
query_editor.setTheme("ace/theme/github");

$('#trees > div').hide();
var all_labels = {
  "investigation": "obo:OBI_0000066",
  "Any assay": "obo:OBI_0000070",
  "part of": "obo:BFO_0000050",
  "participates in": "obo:RO_0000056",
  "inheres in": "obo:RO_0000052",
  "causes or contributes to condition": "obo:RO_0003302",
  "curated information": "obo:OBI_0302840",
  "is about": "obo:IAO_0000136",
  "has specified output": "obo:OBI_0000299",
  "conclusion based on data": "obo:OBI_0001909"
};


// ## Assay Type

var assay_tree = new InspireTree({
  target: '#assay_tree',
  data: []
});
var assay_input = $('#assay_type');
var selected_assay;
assay_input.val('Any assay');
assay_tree.on('node.click', function(event, node) {
  assay_input.val(node.text);
  selected_assay = node;
});
$.getJSON('assay.json', function (data) {
  assay_tree.addNodes(data);
  assay_tree.expand()
  all_labels = Object.assign(all_labels, tree2map(data));
  assay_input.typeahead({
    source: tree2labels(data),
    autoSelect: true
  });
  assay_input.on("focus", function() {
    $('#trees > div').hide();
    $('#assay_tree').show();
  });
});
assay_input.focus();
$('#assay_tree').show();


$('#limit').on('blur', function() {
  try { limit = parseInt($('#limit').val()); }
  catch (e) { limit = 100; }
});


function build_query(options) {
  if (!options) {
    options = {first: limit};
  }
  assay = assay_input.val();
  if (assay == "Any assay" || assay == "assay") {
  } else if (selected_assay && selected_assay.children) {
    options.testId_TestName_In = assay_input.val();
    for (var i=0; i < selected_assay.children.length; i++) {
      options.testId_TestName_In += "," + selected_assay.children[i].text;
    }
  } else {
    options.testName = assay;
  }

  var query = "studyTestDataDomainView(";
  for (var k in options) {
    if (typeof options[k] == "number") {
      query += k +":"+ options[k] + " ";
    } else {
      query += k +":\""+ options[k] + "\" ";
    }
  }
  query += ")"

  var output = "query endpoint_search{\n";
  output += "  " + query + "{\n";
  output += "    pageInfo {\n",
  output += "      startCursor\n",
  output += "      endCursor\n",
  output += "      hasPreviousPage\n",
  output += "      hasNextPage\n",
  output += "    }\n",
  output += "    edges{\n";
  output += "      node{\n";
  output += "        dataDomain\n";
  output += "        testName\n";
  output += "        studyUid{\n";
  output += "          studyTitle\n";
  output += "          VStudyMetadataStudy{\n";
  output += "            edges{\n";
  output += "              node{\n";
  output += "                attrName\n";
  output += "                attrValue\n";
  output += "              }\n";
  output += "            }\n";
  output += "          }\n";
  output += "        }\n";
  output += "      }\n";
  output += "    }\n";
  output += "  }\n";
  output += "}\n";
  query_editor.setValue(output, -1);
  return output;
}

build_query();


query_editor.setOptions({enableBasicAutocompletion: true, enableLiveAutocompletion: true});
var labelCompleter = {
  getCompletions: function(editor, session, pos, prefix, callback) {
    callback(null, Object.keys(all_labels).map(function(word) {
      return {
        caption: word,
        value: "'" + word + "'",
        meta: "static"
      };
    }));
  }
}
var langTools = ace.require("ace/ext/language_tools");
langTools.setCompleters();
langTools.addCompleter(labelCompleter);

var headers = [
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
  "TECH_REPORT_URL"
];

$("#query_result").hide();
function build_table(data) {
  $("#query_result tr").slice(1).remove();
  table = $("#query_result").first();
  table.show();
  var rows = data.data
  for (var i=0; i < rows.length; i++) {
    row = rows[i];
    tr = $("<tr>").appendTo(table);
    for (var j=0; j < headers.length; j++) {
      td = $("<td>").appendTo(tr);
      value = row[headers[j]];
      if (value) {
        td.text(value);
      }
    }
  }

  $("#query_status").text("Showing " + rows.length + " results");

  if (data.pageInfo.hasPreviousPage) {
    $("#query_previous").removeAttr("disabled");
  } else {
    $("#query_previous").attr("disabled", "disabled");
  }
  if (data.pageInfo.hasNextPage) {
    $("#query_next").removeAttr("disabled");
  } else {
    $("#query_next").attr("disabled", "disabled");
  }

  $("#download_json").removeAttr("disabled");
  $("#download_csv").removeAttr("disabled");
  $("#download_xlsx").removeAttr("disabled");
}

function local_query() {
  var query = query_editor.getValue();
  return endpoint + "query.json?query=" + encodeURIComponent(query);
}

function remote_query() {
  var query = query_editor.getValue();
  return graphiql + encodeURIComponent(query);
}


var current = {};
var error = {};
function execute_query() {
  $("#query_status").text("SEARCHING ...");
  $.ajax({
    dataType: "json",
    url: local_query(),
    success: function(data, textStatus, jqXHR) {
      current = data;
      build_table(data);
    },
    error: function(jqXHR, textStatus, errorThrown) {
      error = jqXHR;
      $("#query_status").text("ERROR: " + textStatus + " " + errorThrown);
    }
  });
}

$("#form_search").on("click", function() {
  build_query();
  execute_query();
});
$("#query_search").on("click", function() {
  execute_query();
});
$("#query_open").on("click", function() {
  var query = query_editor.getValue();
  var url = graphiql + encodeURIComponent(query)
  window.open(url);
});
$("#query_first").on("click", function() {
  build_query();
  execute_query();
});
$("#query_previous").on("click", function() {
  build_query({first: limit, before: current.pageInfo.startCursor});
  execute_query();
});
$("#query_next").on("click", function() {
  build_query({first: limit, after: current.pageInfo.endCursor});
  execute_query();
});
$("#query_all").on("click", function() {
  build_query({});
  execute_query();
});

$("#download_json").on("click", function() {
  var url = local_query();
  window.open(url);
});
$("#download_csv").on("click", function() {
  var url = local_query().replace("/query.json", "/query.csv");
  window.open(url);
});
$("#download_xlsx").on("click", function() {
  var url = local_query().replace("/query.json", "/query.xlsx");
  window.open(url);
});
