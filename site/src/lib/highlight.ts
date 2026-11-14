import hljs from 'highlight.js';
import { Marked } from 'marked';
import { markedHighlight } from 'marked-highlight';

const polymorphicColors = ["#a37acc", "#86b300", "#22a4e6", "#eba400"]
const staticColor = "#f07171"
export function kororaHighlighter(name: string) {
  let output = ""
  let nextSection = ""
  let indentation = 0;
  for (const char of name) {
    if (char == "<") {
      output += `<span style="color: ${polymorphicColors[indentation]}">${nextSection}</span>`
      indentation += 1
      output += "&lt"
      nextSection = ""
    } else if (char == ">") {
      output += `<span style="color: ${staticColor};">${nextSection}</span>`
      indentation -= 1
      output += "&gt"
      nextSection = ""
    }
    else if (char == ",") {
      output += `<span style="color: ${staticColor};">${nextSection}</span>`
      output += ","
      nextSection = ""
    }
    else {
      nextSection += char;
    }
  }

  output += `<span style="color: ${staticColor};">${nextSection}</span>`

  return output
}

export let highlighter = hljs;

export const marked = new Marked(markedHighlight({
  emptyLangClass: 'hljs',
  langPrefix: 'hljs language-',
  highlight(code: string, lang: string) {
    const language = hljs.getLanguage(lang) ? lang : 'nix';
    return hljs.highlight(code, { language }).value;
  }
}));
