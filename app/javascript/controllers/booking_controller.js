import { Controller } from "@hotwired/stimulus";

// Connects to data-controller="booking"
export default class extends Controller {
  static targets = [
    "slots",
    "selectedDate",
    "continueButton",
    "form",
    "summary",
    "done",
    "doneDate",
    "doneSlot",
    "pickStep",
  ];

  connect() {
    this.selectedSlot = null;
    this.selectedDay = null;

    this.continueButtonTarget.classList.add("hidden");

    this.slotsByDay = {
      0: [],
      1: ["9:00", "9:30", "10:00", "10:30", "11:00", "13:00"],
      2: ["9:00", "11:00", "13:00", "14:00"],
      3: ["10:00", "11:00", "14:00"],
      4: ["9:00", "10:00", "13:00", "15:00"],
      5: ["9:00", "11:00"],
      6: [],
    };
  }

  selectDay(event) {
    const buttons = document.querySelectorAll(".day-button");

    buttons.forEach((button) => {
      button.classList.remove("border-ink", "bg-ink", "text-cream");

      button.classList.add("border-border", "bg-background");
    });

    event.currentTarget.classList.remove("border-border", "bg-background");

    event.currentTarget.classList.add("border-ink", "bg-ink", "text-cream");

    const day = event.currentTarget.dataset.day;
    const date = event.currentTarget.dataset.date;

    this.selectedDay = day;
    this.selectedSlot = null;

    this.selectedDateTarget.textContent = date;

    this.continueButtonTarget.classList.add("hidden");

    this.renderSlots(day);
  }

  renderSlots(day) {
    const slots = this.slotsByDay[day] || [];

    if (slots.length === 0) {
      this.slotsTarget.innerHTML = `
        <p class="col-span-full py-8 text-sm text-muted-foreground">
          No availability this day.
        </p>
      `;
      return;
    }

    this.slotsTarget.innerHTML = slots
      .map(
        (slot) => `
      <button
        data-slot="${slot}"
        class="
          slot-button rounded-xl border border-border
          bg-background px-3 py-3 text-sm transition
          hover:border-ink/40
        "
      >
        ${slot}
      </button>
    `,
      )
      .join("");

    this.slotsTarget.querySelectorAll(".slot-button").forEach((button) => {
      button.addEventListener("click", () => {
        this.selectSlot(button);
      });
    });
  }

  selectSlot(button) {
    this.slotsTarget.querySelectorAll(".slot-button").forEach((button) => {
      button.classList.remove("border-ink", "bg-ink", "text-cream");
    });

    button.classList.add("border-ink", "bg-ink", "text-cream");

    this.selectedSlot = button.dataset.slot;

    // ONLY show after slot selected
    this.continueButtonTarget.classList.remove("hidden");

    this.continueButtonTarget.innerHTML = `Continue with ${this.selectedSlot} →`;
  }

  continue() {
    if (!this.selectedDay || !this.selectedSlot) {
      return;
    }

    this.pickStepTarget.classList.add("hidden");

    this.formTarget.classList.remove("hidden");

    this.summaryTarget.textContent = `${this.selectedDateTarget.textContent} at ${this.selectedSlot}`;
  }

  back() {
    this.formTarget.classList.add("hidden");

    this.pickStepTarget.classList.remove("hidden");
  }

  confirm() {
    this.formTarget.classList.add("hidden");

    this.doneTarget.classList.remove("hidden");

    this.doneDateTarget.textContent = this.selectedDateTarget.textContent;

    this.doneSlotTarget.textContent = `${this.selectedSlot} · 30 minutes`;
  }
}
