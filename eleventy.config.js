const markdownIt = require("markdown-it");

module.exports = function (eleventyConfig) {
  eleventyConfig.addPassthroughCopy({ "src/styles.css": "styles.css" });
  eleventyConfig.addPassthroughCopy({ "src/images": "images" });

  const md = markdownIt({ html: true });
  eleventyConfig.addFilter("markdownify", (value) => md.render(value || ""));

  return {
    dir: { input: "src", output: "_site", includes: "_includes" },
    htmlTemplateEngine: "njk",
  };
};
