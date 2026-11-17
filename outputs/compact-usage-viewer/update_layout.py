from pathlib import Path
import textwrap

root = Path('O:/GitHub/StaticBlazorSnomed/StaticBlazorSnomed')
page = root / 'Pages/UsageViewerSyncFu.razor'
css = root / 'Pages/UsageViewerSyncFu.razor.css'
original = page.read_text(encoding='utf-8-sig')
original_css = css.read_text(encoding='utf-8-sig')
out = Path(__file__).parent
(out / 'UsageViewerSyncFu.before.razor').write_text(original, encoding='utf-8')
(out / 'UsageViewerSyncFu.before.razor.css').write_text(original_css, encoding='utf-8')

start = original.index('<div class="container-fluid usage-viewer">')
end = original.index('    <!-- Usage Scale Legend -->', start)
concept_start = original.index('                                <label for="usage-concept-search"', start)
concept_end = original.index('                                <label for="snomedCodes"', concept_start)
concept = textwrap.dedent(original[concept_start:concept_end]).strip()
concept = concept.replace('class="small text-muted mt-1" role="status"', 'class="small text-muted usage-concept-status" hidden="@(!isLoadingSuggestions && string.IsNullOrEmpty(suggestionMessage))" role="status"')
template_start = original.index('                                        <SfButton @onclick="() => SetExampleCodes', start)
template_end = original.index('                                    </div>', template_start)
templates = textwrap.dedent(original[template_start:template_end]).strip()

search = '''<div class="container-fluid usage-viewer">
    <p class="small text-muted usage-release-note">
        Latest release: <a href="https://digital.nhs.uk/data-and-information/publications/statistical/mi-snomed-code-usage-in-primary-care/2025-26" target="_blank" rel="noopener noreferrer">2025-26</a>, covering 1 August 2025 to 31 July 2026 (England).
    </p>
    <div class="content-section">
        <div class="card usage-search-card">
            <div class="card-body">
                <div class="usage-search-fields">
                    <div class="usage-search-field">
CONCEPT
                    </div>
                    <div class="usage-codes-field">
                        <label for="snomedCodes" class="form-label fw-bold mb-1">SNOMED CT codes to compare</label>
                        <div class="usage-code-controls">
                            <textarea id="snomedCodes" class="form-control snomed-textarea" rows="1"
                                      @bind="searchCodes" @bind:event="oninput" disabled="@isLoading"
                                      placeholder="Enter SNOMED CT codes"
                                      aria-describedby="usage-codes-help"></textarea>
                            <div class="usage-search-actions">
                                <SfButton @onclick="SearchUsageData" Disabled="@isLoading" CssClass="e-primary e-small">
                                    @if (isLoading)
                                    {
                                        <span class="spinner-border spinner-border-sm me-1" role="status"></span>
                                    }
                                    SEARCH
                                </SfButton>
                                <SfButton @onclick="ClearData" Disabled="@isLoading" CssClass="e-outline e-small">CLEAR</SfButton>
                            </div>
                        </div>
                        <small id="usage-codes-help" class="form-text text-muted">Add concepts or paste comma-separated codes.</small>
                    </div>
                </div>
                <details class="usage-templates">
                    <summary>Quick search templates</summary>
                    <div class="usage-template-menu">
                        <small class="text-muted">Choose a template, then SEARCH.</small>
TEMPLATES
                    </div>
                </details>
            </div>
        </div>

'''
search = search.replace('CONCEPT', textwrap.indent(concept, ' ' * 24)).replace('TEMPLATES', textwrap.indent(templates, ' ' * 24))
updated = original[:start] + search + original[end:]
updated = updated.replace('<div class="row mb-2">', '<div class="row usage-legend">', 1)
updated = updated.replace('<div class="d-flex flex-wrap align-items-center gap-2">', '<div class="d-flex flex-wrap align-items-center gap-1">')
first_css = updated.index('    .snomed-textarea {')
first_css_end = updated.index('</style>', first_css)
updated = updated[:first_css] + updated[first_css_end:]
last_style = updated.rfind('\n<style>')
assert last_style > updated.index('@code {')
updated = updated[:last_style].rstrip() + '\n'
assert updated.count('padding: 4px; border-radius: 3px;') == 7
updated = updated.replace(' padding: 4px; border-radius: 3px;', '')

suggestions = original_css[original_css.index('.usage-concept-search {'):original_css.index('@media (max-width: 767.98px)')]
compact_css = '''.usage-viewer {
    margin-top: 0;
    padding: 0.25rem 0.5rem;
}

.usage-release-note {
    margin-bottom: 0.35rem;
}

.usage-search-card {
    margin-bottom: 0.4rem;
}

.usage-search-card .card-body {
    padding: 0.5rem 0.65rem;
}

.usage-search-fields {
    display: grid;
    grid-template-columns: minmax(0, 1fr) minmax(0, 1fr);
    gap: 0.4rem 1rem;
    align-items: start;
}

.usage-search-field,
.usage-codes-field {
    min-width: 0;
}

.usage-search-card .form-label {
    font-size: 0.875rem;
}

.usage-search-card .form-control {
    min-height: 2rem;
    padding: 0.25rem 0.5rem;
    font-size: 0.875rem;
    line-height: 1.4;
}

.usage-search-card .form-text,
.usage-concept-status {
    margin-top: 0.15rem;
    font-size: 0.75rem;
    line-height: 1.35;
}

.usage-code-controls {
    display: flex;
    align-items: flex-start;
    gap: 0.4rem;
}

.usage-search-card .snomed-textarea {
    height: 2rem;
    min-width: 0;
    font-family: 'Courier New', monospace;
    resize: vertical;
}

.usage-search-actions {
    display: flex;
    flex: none;
    gap: 0.3rem;
}

.usage-search-actions ::deep .e-btn {
    min-height: 2rem;
    padding: 0.25rem 0.5rem;
    line-height: 1.4;
}

.usage-templates {
    position: relative;
    width: fit-content;
    max-width: 100%;
    margin-top: 0.3rem;
    font-size: 0.75rem;
}

.usage-templates summary {
    cursor: pointer;
    color: #005eb8;
    padding: 0.1rem 0;
}

.usage-template-menu {
    position: absolute;
    z-index: 1040;
    top: 100%;
    left: 0;
    display: flex;
    flex-direction: column;
    width: min(30rem, calc(100vw - 3rem));
    padding: 0.5rem 0.75rem;
    background: #fff;
    border: 1px solid #b8c5d6;
    border-radius: 0.3rem;
    box-shadow: 0 0.25rem 0.75rem rgba(0, 0, 0, 0.12);
}

.usage-templates ::deep .e-btn.e-link {
    min-height: 1.75rem;
    padding: 0.2rem 0;
    max-width: 100%;
    white-space: normal;
    text-align: left;
}

.usage-legend {
    margin-bottom: 0.35rem;
    font-size: 0.8rem;
}

.usage-legend .badge {
    margin: 0;
    padding: 0.2em 0.4em;
    line-height: 1.25;
}

.usage-results .card-header {
    min-height: 0;
    padding: 0.25rem 0.5rem;
    gap: 0.5rem;
    font-size: 0.85rem;
}

.usage-results .card-header ::deep .e-btn {
    min-height: 1.5rem;
    padding: 0.15rem 0.35rem;
}

.usage-results .table {
    margin-bottom: 0;
}

.usage-results .table > :not(caption) > * > * {
    padding: 0.15rem 0.3rem;
    line-height: 1.3;
    white-space: nowrap;
    vertical-align: middle;
}

.usage-cell {
    display: block;
    padding: 0.1rem 0.25rem;
    border-radius: 3px;
    font-weight: 500;
    text-align: center;
    font-variant-numeric: tabular-nums;
}

.procedure-description {
    color: #343a40;
    font-weight: 600;
}

'''
compact_css += suggestions
compact_css += '''@media (max-width: 991.98px) {
    .usage-search-fields {
        grid-template-columns: minmax(0, 1fr);
        gap: 0.5rem;
    }
}

@media (max-width: 767.98px) {
    .usage-search-card .form-control,
    .usage-search-actions ::deep .e-btn {
        min-height: 2.5rem;
    }

    .usage-search-card .form-control {
        font-size: 1rem;
    }

    .usage-templates summary {
        padding: 0.4rem 0;
    }

    .usage-templates ::deep .e-btn.e-link,
    .usage-suggestion {
        min-height: 44px;
    }

    .usage-suggestion {
        gap: 0.5rem;
    }
}
'''
page.write_text(updated, encoding='utf-8', newline='\r\n')
css.write_text(compact_css, encoding='utf-8', newline='\r\n')
print('Updated the usage viewer layout and scoped styles; preserved search and result logic.')
