var endpoint = "https://manticore.niehs.nih.gov/cebsr-api#operationName=endpoint_search&query="
var offset = 0;
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


function build_query() {
  var template;
  var output = "query endpoint_search{\n";
  if (selected_assay && selected_assay.children) {
    output += "  studyTestDataDomainView(testId_TestName_In:\"";
    output += assay_input.val();
    for (var i=0; i < selected_assay.children.length; i++) {
      output += "," + selected_assay.children[i].text;
    }
    output += "\", first:20){\n";
  } else {
    output += "  studyTestDataDomainView(testName:\"";
    output += assay_input.val();
    output += "\", first:20){\n";
  }
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
  query_editor.setValue(output);
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


function execute_query() {
  $("#query_result").text("SEARCHING ...").show();
  var query = query_editor.getValue();
  var url = endpoint + encodeURIComponent(query)
  window.open(url);
}

$("#query_result_box").hide();
$("#form_search").on("click", function() {
  offset = 0;
  $("#query_result_box").show();
  build_query();
  execute_query();
});
$("#query_search").on("click", function() {
  offset = 0;
  $("#query_result_box").show();
  execute_query();
});
