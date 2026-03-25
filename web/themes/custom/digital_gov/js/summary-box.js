/**
 * Guide Table of Contents
 * Replaces guidenav.js that used Hugo's .TableOfContents with USWDS summary-box — https://designsystem.digital.gov/components/summary-box/#package.
 * Get all H2's on a page and display a bulleted list of links when setting summary_box: true in the front matter of a guide page.
 * See a live example used on https://digital.gov/guides/dap/common-questions-about-dap/ that displays this page: content/guides/dap/common-questions-about-dap.md.

 */
// eslint-disable-next-line func-names
(function () {
  const guideSummary = document.querySelector(".dg-guide-summary");

  if (!guideSummary) return;

  const guideSummaryList = guideSummary.querySelector(".usa-list");
  /**
   * Return a list of h2's to display in the summary box. We want h2s:
   *  - from the body of the page only (div.dg-guide__content_body)
   *  - not the summary box heading (.usa-summary-box__heading)
   *  - not a few other things (note .visually-hidden is not reliable)
   * We will also skip h2s without IDs in the createSummaryBox loop.
   */
  const pageHeaders = document.querySelectorAll(
    "div.dg-guide__content-body > h2:not(.usa-summary-box__heading, .dg-guide__content-header-title, .dg-glossary__header, .visually-hidden)"
  );

  /**
   * Populate the summary box with bulleted list of links created from the current page's h2's
   */
  function createSummaryBox() {
    const summaryBoxFragment = document.createDocumentFragment();
    pageHeaders.forEach((link) => {
      if (link.id) { // skip, not a link.
          const summaryListItem = document.createElement("li");

          const summaryLink = Object.assign(document.createElement("a"), {
              class: "usa-summary-box__link",
              href: `#${link.id}`,
              innerHTML: `${link.innerText}`,
          });

          summaryListItem.appendChild(summaryLink);
          summaryBoxFragment.appendChild(summaryListItem);
      }
    });

    guideSummaryList.appendChild(summaryBoxFragment);
  }

  createSummaryBox();
})();
