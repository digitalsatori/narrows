const {schema: baseSchema} = require("prosemirror-schema-basic");
const model = require("prosemirror-model"),
      Schema = model.Schema,
      Mark = model.Mark,
      MarkType = model.MarkType,
      Attribute = model.Attribute,
      Fragment = model.Fragment;
const {addListNodes} = require("prosemirror-schema-list");

const chapterMarkSpec = baseSchema.spec.marks.append({mention: {
    attrs: {
        mentionTargets: {default: []}
    },
    parseDOM: [{tag: "span[data-mentions]", getAttrs(dom) {
        return {mentionTargets: JSON.parse(dom.getAttribute("data-mentions"))};
    }}],
    toDOM(node) {
        const targets = node.attrs.mentionTargets;

        return [
            "span",
            {"data-mentions": JSON.stringify(targets),
             "class": "mention" + targets.map(t => ` mention-${t.id % 5 + 1}`).join(""),
             "title": "Only for " + targets.map(t => t.name).join(", ")
            }
        ];
    }
}});

const nodeSpecWithLists = addListNodes(
    baseSchema.spec.nodes,
    "paragraph block*",
    "block"
).addToEnd(
    "horizontal_rule",
    {
        group: "block",
        parseDOM: [{tag: "hr"}, {tag: "div[class='separator']"}],
        toDOM() { return ["div", {class: "separator"}]; }
    }
);
const chapterSchema = new Schema({
  nodes: nodeSpecWithLists,
  marks: chapterMarkSpec
});

const narrationIntroSchema = new Schema({
  nodes: nodeSpecWithLists,
  marks: baseSchema.spec.marks
});

const descriptionSchema = new Schema({
  nodes: nodeSpecWithLists.remove("image"),
  marks: baseSchema.spec.marks
});

module.exports.chapter = chapterSchema;
module.exports.narrationIntro = narrationIntroSchema;
module.exports.description = descriptionSchema;
