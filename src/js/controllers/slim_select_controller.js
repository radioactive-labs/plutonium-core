import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="slim-select"
export default class extends Controller {
  connect() {
    const settings = {};
    const modal = document.querySelector('[data-controller="remote-modal"]');

    if (modal) {
      // Create a dedicated container div right after the select element
      this.dropdownContainer = document.createElement("div");
      this.dropdownContainer.className = "ss-dropdown-container";

      // Make the select wrapper position relative to contain the absolute dropdown
      const selectWrapper = this.element.parentNode;
      const originalPosition = getComputedStyle(selectWrapper).position;
      if (originalPosition === "static") {
        selectWrapper.style.position = "relative";
        this.modifiedSelectWrapper = selectWrapper;
      }

      // Insert the container right after the select element
      this.element.parentNode.insertBefore(
        this.dropdownContainer,
        this.element.nextSibling
      );

      settings.contentLocation = this.dropdownContainer;
      settings.contentPosition = "absolute";
      settings.openPosition = "auto";
    }

    this.slimSelect = new SlimSelect({
      select: this.element,
      settings: settings,
    });

    // Add event listeners for better positioning
    this.handleDropdownPosition();

    // Bind event handlers for proper cleanup
    this.boundHandleDropdownOpen = this.handleDropdownOpen.bind(this);
    this.boundHandleDropdownClose = this.handleDropdownClose.bind(this);

    // Add event listeners to properly handle dropdown visibility
    this.element.addEventListener("ss:open", this.boundHandleDropdownOpen);
    this.element.addEventListener("ss:close", this.boundHandleDropdownClose);

    // Add mutation observer to track aria-expanded attribute
    this.setupAriaObserver();

    this.element.setAttribute(
      "data-action",
      "turbo:morph-element->slim-select#reconnect"
    );
  }

  handleDropdownPosition() {
    if (this.dropdownContainer) {
      // Reposition dropdown when window resizes or scrolls
      const repositionDropdown = () => {
        const selectRect = this.element.getBoundingClientRect();

        // Calculate if there's enough space below
        const spaceBelow = window.innerHeight - selectRect.bottom;
        const spaceAbove = selectRect.top;

        if (spaceBelow < 200 && spaceAbove > spaceBelow) {
          // Position above if not enough space below
          this.dropdownContainer.style.top = "auto";
          this.dropdownContainer.style.bottom = "100%";
          this.dropdownContainer.style.borderRadius = "0.375rem 0.375rem 0 0";
        } else {
          // Position below (default)
          this.dropdownContainer.style.bottom = "auto";
          this.dropdownContainer.style.borderRadius = "0 0 0.375rem 0.375rem";
        }
      };

      // Initial positioning
      setTimeout(repositionDropdown, 0);

      // Reposition on events
      window.addEventListener("resize", repositionDropdown);
      window.addEventListener("scroll", repositionDropdown);

      // Store references for cleanup
      this.repositionDropdown = repositionDropdown;
    }
  }

  handleDropdownOpen() {
    if (this.dropdownContainer) {
      // When dropdown opens, ensure our container is properly sized
      this.dropdownContainer.style.height = "auto";
      this.dropdownContainer.style.overflow = "visible";

      // Add open class for better CSS targeting
      this.dropdownContainer.classList.add("ss-active");

      // Ensure this dropdown appears above others
      const allContainers = document.querySelectorAll(".ss-dropdown-container");
      allContainers.forEach((container) => {
        if (container !== this.dropdownContainer) {
          container.style.zIndex = "9999";
        }
      });
      this.dropdownContainer.style.zIndex = "10000";
    }
  }

  handleDropdownClose() {
    if (this.dropdownContainer) {
      // Remove active class
      this.dropdownContainer.classList.remove("ss-active");
    }
  }

  setupAriaObserver() {
    // Track aria-expanded attribute on the select element or its wrapper
    if (this.element) {
      this.ariaObserver = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (mutation.attributeName === "aria-expanded") {
            const expanded =
              mutation.target.getAttribute("aria-expanded") === "true";
            if (expanded) {
              this.handleDropdownOpen();
            } else {
              this.handleDropdownClose();
            }
          }
        });
      });

      // Look for the actual element that gets the aria-expanded attribute
      const possibleTargets = [
        this.element,
        this.element.parentNode.querySelector(".ss-main"),
        this.element.parentNode.querySelector("[aria-expanded]"),
      ];

      const target = possibleTargets.find(
        (el) => el && el.hasAttribute && el.hasAttribute("aria-expanded")
      );

      if (target) {
        this.ariaObserver.observe(target, {
          attributes: true,
          attributeFilter: ["aria-expanded"],
        });

        // Check initial state
        const expanded = target.getAttribute("aria-expanded") === "true";
        if (expanded) {
          this.handleDropdownOpen();
        } else {
          this.handleDropdownClose();
        }
      }
    }
  }

  disconnect() {
    // Clean up event listeners
    if (this.element) {
      if (this.boundHandleDropdownOpen) {
        this.element.removeEventListener(
          "ss:open",
          this.boundHandleDropdownOpen
        );
      }
      if (this.boundHandleDropdownClose) {
        this.element.removeEventListener(
          "ss:close",
          this.boundHandleDropdownClose
        );
      }
    }

    // Disconnect observer
    if (this.ariaObserver) {
      this.ariaObserver.disconnect();
      this.ariaObserver = null;
    }

    if (this.slimSelect) {
      this.slimSelect.destroy();
      this.slimSelect = null;
    }

    // Clean up event listeners
    if (this.repositionDropdown) {
      window.removeEventListener("resize", this.repositionDropdown);
      window.removeEventListener("scroll", this.repositionDropdown);
      this.repositionDropdown = null;
    }

    // Clean up the dropdown container if it exists
    if (this.dropdownContainer && this.dropdownContainer.parentNode) {
      this.dropdownContainer.parentNode.removeChild(this.dropdownContainer);
      this.dropdownContainer = null;
    }

    // Restore original positioning if we modified it
    if (this.modifiedSelectWrapper) {
      this.modifiedSelectWrapper.style.position = "";
      this.modifiedSelectWrapper = null;
    }
  }

  reconnect() {
    this.disconnect();
    // dispatch this on the next frame.
    // there's some funny issue where my elements get removed from the DOM
    setTimeout(() => this.connect(), 10);
  }
}
