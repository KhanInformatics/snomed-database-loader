from pathlib import Path
import json
from playwright.sync_api import sync_playwright

folder = Path(__file__).resolve().parent
with sync_playwright() as p:
    browser = p.chromium.launch(channel="msedge", headless=True)
    page = browser.new_page(viewport={"width": 1056, "height": 1250}, device_scale_factor=1)
    errors = []
    page.on("pageerror", lambda error: errors.append(str(error)))
    page.goto((folder / "preview.html").as_uri(), wait_until="load")
    frame = page.frames[1]
    frame.wait_for_selector("#term-log-preview .tl-step")
    assert frame.locator(".tl-step").count() == 5
    assert "Validating Primary Care" in frame.locator('[data-role="headline"]').inner_text()
    frame.locator(".tl-step summary").first.click()
    assert frame.locator(".tl-step").first.get_attribute("open") is not None
    assert "1,152,579" in frame.locator(".tl-step-content").first.inner_text()
    frame.locator(".tl-step summary").first.click()
    page.screenshot(path=str(folder / "desktop-light.png"), full_page=True)

    frame.locator('[data-run="failed"]').click()
    assert "Report publishing failed" in frame.locator('[data-role="headline"]').inner_text()
    assert frame.locator('.tl-step[data-state="failed"]').count() == 1
    assert frame.locator('.tl-step[data-state="done"]').count() == 4
    frame.locator(".tl-step summary").last.click()
    assert "6 Sep 2026" in frame.locator(".tl-step-content").last.inner_text()
    page.screenshot(path=str(folder / "reporting-failed.png"), full_page=True)
    frame.locator(".tl-step summary").last.click()

    frame.locator('[data-run="complete"]').click()
    assert frame.locator('.tl-step[data-state="done"]').count() == 5
    assert frame.locator('[data-run="complete"]').get_attribute("aria-pressed") == "true"
    # Replay the fragment initialization with a test double for the optional
    # conversation helper, which the standalone renderer does not supply.
    frame.evaluate("""() => {
      window.mockTweaks=[];
      window.Tweak=class {
        constructor(options){this.options=options;window.mockTweaks.push(this);}
        addSelect(object,key,options){this.state=object;}
        addToggle(object,key,options){this.state=object;}
      };
      (0,eval)(document.querySelector('#term-log-preview script').textContent);
    }""")
    frame.evaluate("mockTweaks[0].state.state='stale';mockTweaks[0].options.onChange();")
    assert "Waiting for an update" in frame.locator('[data-role="headline"]').inner_text()
    assert frame.locator('.tl-step[data-state="stale"]').count() == 1
    frame.evaluate("mockTweaks[0].state.state='running';mockTweaks[0].options.onChange();")

    sizes = []
    for width in [1056, 768, 392, 352]:
        page.set_viewport_size({"width": width, "height": 1500})
        frame.wait_for_function("expected => window.innerWidth === expected", arg=width - 32)
        for scheme in ["light", "dark"]:
            page.emulate_media(color_scheme=scheme)
            size = frame.evaluate("""(() => {
                const root=document.getElementById('term-log-preview');
                return {viewport:window.innerWidth,scroll:document.documentElement.scrollWidth,
                    root:root.getBoundingClientRect().width};
            })()""")
            assert size["scroll"] <= size["viewport"] + 1, size
            sizes.append({"scheme":scheme,**size})
            if width == 392:
                page.screenshot(path=str(folder / f"mobile-{scheme}.png"), full_page=True)
            if width == 1056 and scheme == "dark":
                page.screenshot(path=str(folder / "desktop-dark.png"), full_page=True)
    assert not errors, errors
    print(json.dumps({"interaction_checks":"passed","page_errors":errors,"layout_checks":sizes}))
    browser.close()
