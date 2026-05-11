# Smooth - Business Logic & Product Rules

**Complete business logic documentation for a booking and scheduling SaaS product**

---

## Table of Contents

1. [Product Overview](#product-overview)
2. [Core Entities & Concepts](#core-entities--concepts)
3. [Availability System (The Engine)](#availability-system-the-engine)
4. [Booking Creation Logic](#booking-creation-logic)
5. [Conflict Prevention & Slot Locking](#conflict-prevention--slot-locking)
6. [Timezone Handling](#timezone-handling)
7. [Cancellation & Rescheduling](#cancellation--rescheduling)
8. [Notification & Reminder System](#notification--reminder-system)
9. [User Roles & Permissions](#user-roles--permissions)
10. [Business Rules & Constraints](#business-rules--constraints)
11. [Edge Cases & Solutions](#edge-cases--solutions)
12. [Monetization Logic](#monetization-logic)

---

## Product Overview

### What Smooth Does

Smooth eliminates the "when are you free?" email back-and-forth by letting professionals:
1. Define when they're available
2. Share one public link
3. Let clients pick available times themselves

### The Three Core Actors

1. **Professional** (Account holder, has login)
    - Sets availability schedule
    - Defines what types of meetings they offer
    - Manages bookings from dashboard
    - Pays subscription fee

2. **Client** (No account needed)
    - Visits professional's public booking page
    - Sees available times in their timezone
    - Books a slot by filling out a form
    - Gets email confirmation with calendar invite

3. **System** (Automated agent)
    - Calculates available slots in real-time
    - Prevents double-booking
    - Sends emails and reminders
    - Handles timezone conversions

### Value Proposition

**For Professionals:**
- "Stop playing calendar Tetris via email"
- Get back 2-3 hours per week spent coordinating schedules
- Appear more professional with a dedicated booking link

**For Clients:**
- "Book instantly without waiting for a reply"
- See availability transparently
- Choose a time that actually works for them

---

## Core Entities & Concepts

### 1. Professional (User Account)

**Data:**
- Username (becomes their public URL: `smooth.com/alice`)
- Email, password (authentication)
- Full name, bio, profile photo (shown on booking page)
- Timezone (their "home" timezone for all time calculations)
- Subscription plan (free/starter/pro)

**Uniqueness rules:**
- Username must be globally unique (case-insensitive)
- Email must be unique (one account per email)
- Username can only contain letters, numbers, hyphens (no spaces, special chars)

### 2. Meeting Type

A professional can offer multiple types of meetings. Each type has different duration and purpose.

**Data:**
- Name: "30-min Consultation", "60-min Strategy Call", "15-min Quick Chat"
- Duration: How long the meeting lasts (15, 30, 45, 60, 90 minutes)
- Buffer time: Break needed after the meeting (0, 15, 30 minutes)
- Description: Shown to clients so they pick the right meeting type
- Active/Inactive: Professional can turn off meeting types temporarily

**Example:**
```
Meeting Type 1:
Name: "Quick Chat"
Duration: 15 minutes
Buffer: 0 minutes
Description: "A quick introduction call"

Meeting Type 2:
Name: "Deep Dive Session"
Duration: 60 minutes
Buffer: 15 minutes
Description: "In-depth strategy discussion"
```

**Why buffer time matters:**
Buffer prevents back-to-back meetings. If a client books 2pm-3pm with 15-minute buffer, the next available slot is 3:15pm, not 3:00pm. This gives the professional time to decompress, take notes, or grab water.

### 3. Availability Slot (Weekly Recurring Schedule)

This defines when the professional is generally available each week.

**Data:**
- Day of week (Monday, Tuesday, ..., Sunday)
- Start time (e.g., 9:00 AM)
- End time (e.g., 5:00 PM)

**Key rules:**
- A professional can have multiple slots per day
- Slots cannot overlap on the same day
- Times are stored in the professional's timezone
- This is a RECURRING schedule (applies every week)

**Example: A consultant's availability**
```
Monday: 9:00 AM - 12:00 PM, 1:00 PM - 5:00 PM (lunch break 12-1)
Tuesday: 1:00 PM - 6:00 PM (works afternoon only)
Wednesday: Not available (no slots)
Thursday: 9:00 AM - 5:00 PM
Friday: 9:00 AM - 3:00 PM (half day)
Saturday: Not available
Sunday: Not available
```

**What this means:**
Every Monday, the professional is available 9am-12pm and 1pm-5pm. This repeats every week automatically.

### 4. Blocked Date (One-Off Unavailability)

Sometimes the professional is unavailable on specific dates that don't fit their weekly pattern.

**Data:**
- Date (e.g., December 25, 2024)
- Reason (optional, e.g., "Holiday", "Conference", "Sick day")

**Purpose:**
Overrides the weekly schedule for specific dates.

**Example:**
```
Blocked Date: May 20, 2024 (Reason: "Attending conference")
Blocked Date: May 27, 2024 (Reason: "Memorial Day")
```

Even if the professional is normally available on Mondays, May 20 and May 27 will show NO available slots.

### 5. Booking (A Scheduled Meeting)

Represents an actual appointment between professional and client.

**Data:**
- Which professional (user_id)
- Which meeting type (meeting_type_id)
- Client's name
- Client's email
- Client's optional message
- Start datetime (in UTC)
- End datetime (in UTC)
- Client's timezone at time of booking (for reference)
- Status: `scheduled`, `cancelled`, `completed`
- Cancellation token (secret URL parameter for magic cancel link)
- Reschedule token (secret URL parameter for magic reschedule link)

**Status transitions:**
```
scheduled → cancelled (client or professional cancels)
scheduled → completed (automatically after meeting end time passes)
```

---

## Availability System (The Engine)

This is the most complex part of Smooth. The system must calculate which time slots are available for booking, accounting for:
1. Weekly recurring availability
2. Blocked dates
3. Existing bookings
4. Meeting duration + buffer time
5. Timezone conversion
6. Booking window (how far in advance clients can book)

### Step-by-Step: Calculating Available Slots

**Input:**
- Professional's username
- Meeting type selected by client
- Date range (e.g., next 14 days)
- Client's timezone

**Process:**

#### Step 1: Generate Base Slots from Weekly Schedule

For each day in the date range:
1. Check if there's a blocked date for that day → if yes, skip entirely
2. Find the availability slots for that day of week
3. For each availability slot, generate possible meeting start times

**Example:**
```
Professional's availability: Monday 9am-5pm
Meeting type duration: 30 minutes
Date: Monday, May 13, 2024

Generated slots:
9:00am, 9:30am, 10:00am, 10:30am, 11:00am, 11:30am,
12:00pm, 12:30pm, 1:00pm, 1:30pm, 2:00pm, 2:30pm,
3:00pm, 3:30pm, 4:00pm, 4:30pm

(4:30pm is the last slot because meeting ends at 5:00pm)
```

**Why every 30 minutes?**
The system generates slots at intervals matching the meeting duration. For 30-minute meetings, slots are every 30 minutes. For 60-minute meetings, slots are every hour.

**Refinement for irregular durations:**
For 15-minute meetings, generate slots every 15 minutes.
For 45-minute meetings, generate slots every 15 minutes but show that each booking takes 45 minutes.

#### Step 2: Remove Slots Conflicting with Existing Bookings

For each generated slot:
1. Calculate when the meeting would START and END (including buffer time)
2. Query all existing bookings for this professional
3. If the proposed time overlaps with any existing booking, mark as UNAVAILABLE

**Example:**
```
Generated slot: 2:00pm
Meeting duration: 30 minutes
Buffer time: 15 minutes
Total time blocked: 2:00pm - 2:45pm

Existing booking: 2:30pm - 3:00pm

Overlap detected! → Mark 2:00pm as UNAVAILABLE
```

**Overlap logic:**
Two time ranges overlap if:
```
(Start1 < End2) AND (Start2 < End1)
```

**Why buffer matters here:**
If a meeting is 2:00-2:30 with 15-minute buffer, the time is blocked until 2:45pm. So the 2:30pm slot is NOT available even though the meeting itself ends at 2:30pm.

#### Step 3: Apply Booking Window Restrictions

**Business rule:** Clients cannot book too far in the future or too last-minute.

**Settings (configurable per professional):**
- **Minimum notice:** How soon can clients book? (e.g., 2 hours in advance)
- **Maximum advance:** How far ahead can clients book? (e.g., 60 days)

**Example:**
```
Current time: Monday 10:00am
Minimum notice: 2 hours

Slots at 10:30am, 11:00am → UNAVAILABLE (less than 2 hours away)
Slots at 12:30pm, 1:00pm, ... → AVAILABLE
```

**Why this matters:**
- Minimum notice prevents clients from booking a slot that starts in 5 minutes when the professional might not check their email
- Maximum advance prevents booking slots 6 months out when the professional's schedule might change

#### Step 4: Convert to Client's Timezone

All slots are calculated in the professional's timezone, then converted to the client's timezone for display.

**Example:**
```
Professional timezone: America/New_York (EST)
Client timezone: Europe/London (GMT)
Available slot in professional's time: 2:00pm EST

Display to client: 7:00pm GMT
```

**Critical rule:** All calculations happen in UTC or professional's timezone. Conversion to client's timezone is DISPLAY ONLY.

#### Step 5: Return Available Slots

**Output format:**
```json
[
  {
    "start_time": "2024-05-13T14:00:00Z",  // UTC
    "display_time": "7:00 PM",              // Client's timezone
    "timezone": "Europe/London",
    "available": true
  },
  {
    "start_time": "2024-05-13T14:30:00Z",
    "display_time": "7:30 PM",
    "timezone": "Europe/London",
    "available": true
  }
]
```

### Slot Increment Logic

**Question:** How often should slots appear?

**Answer depends on meeting duration:**

- **15-minute meetings:** Slots every 15 minutes
    - 9:00, 9:15, 9:30, 9:45, 10:00, ...

- **30-minute meetings:** Slots every 30 minutes
    - 9:00, 9:30, 10:00, 10:30, ...

- **60-minute meetings:** Slots every 30 minutes (more flexibility)
    - 9:00, 9:30, 10:00, 10:30, ...
    - Why not every hour? Clients might prefer 9:30am over 9:00am

**Best practice:** Always generate slots at 15 or 30-minute increments regardless of meeting duration, then check if the full meeting + buffer fits.

---

## Booking Creation Logic

### The Booking Flow (Step-by-Step)

#### 1. Client Selects a Slot

Client clicks on "3:00 PM" on the calendar.

**What happens:**
- System records the selected slot (stored temporarily, not saved yet)
- Booking form appears (name, email, message fields)

#### 2. Client Submits Form

Client fills out:
- Name: "John Smith"
- Email: "john@example.com"
- Message: "Looking forward to discussing the project"

Clicks "Confirm Booking"

#### 3. Server-Side Validation (CRITICAL)

Even though the slot appeared available, the system MUST re-check availability before creating the booking. Why? Another client might have booked the same slot 2 seconds ago.

**Validation steps:**

**A. Check slot is still available**
```
Input:
- Professional's user_id
- Meeting type_id
- Requested start time

Process:
1. Recalculate available slots for that day
2. Check if requested time is in the available list

If NOT available → Return error: "Sorry, this time was just booked by someone else. Please choose another."
If available → Continue
```

**B. Validate form data**
- Name: Required, max 100 characters
- Email: Required, valid email format
- Message: Optional, max 500 characters

**C. Check for duplicate bookings from same email**

Business rule: Prevent the same email from booking multiple overlapping slots with the same professional.

```
Check if this email already has a scheduled booking 
with this professional in the next 48 hours.

If yes → Ask "You already have a booking on [date] at [time]. 
           Do you want to reschedule that one instead?"
```

#### 4. Create the Booking

**Database transaction (all-or-nothing):**

1. Calculate end time:
   ```
   start_time = requested_time
   end_time = start_time + meeting_duration
   ```

2. Generate secret tokens:
   ```
   cancellation_token = random_secure_string(32)
   reschedule_token = random_secure_string(32)
   ```

3. Insert booking record:
   ```
   Booking {
     user_id: professional's ID
     meeting_type_id: selected meeting type
     attendee_name: "John Smith"
     attendee_email: "john@example.com"
     attendee_message: "Looking forward..."
     starts_at: "2024-05-13 15:00:00 UTC"
     ends_at: "2024-05-13 15:30:00 UTC"
     timezone: "America/New_York" (client's detected timezone)
     status: "scheduled"
     cancellation_token: "abc123..."
     reschedule_token: "xyz789..."
   }
   ```

4. Trigger notifications:
    - Queue email to client
    - Queue email to professional
    - Schedule reminder email (1 hour before meeting)

5. Broadcast real-time update:
    - Send WebSocket message to all viewers of this booking page
    - Message: "Slot 3:00pm is now unavailable"

#### 5. Response to Client

**Success screen shows:**
- ✓ Booking confirmed
- Meeting details (date, time in their timezone, duration)
- Professional's name
- "Calendar invite has been sent to john@example.com"
- "Check your email for meeting details"
- Links:
    - "Add to Google Calendar"
    - "Download .ics file"
    - "Reschedule" (goes to reschedule page with token)
    - "Cancel" (goes to cancel page with token)

---

## Conflict Prevention & Slot Locking

### The Double-Booking Problem

**Scenario:**
- Client A views the booking page at 2:00pm, sees 3:00pm available
- Client B views the booking page at 2:00pm, sees 3:00pm available
- Client A clicks 3:00pm at 2:01pm, fills out form for 30 seconds
- Client B clicks 3:00pm at 2:01pm, fills out form for 30 seconds
- Both submit at 2:01:30pm
- Without protection → BOTH get the slot (double-booked!)

### Solution 1: Optimistic Locking (Recommended)

**How it works:**

1. **No pre-locking.** Multiple clients can start the booking form simultaneously.

2. **At submission time:** Use database constraints + validation

```
When creating a booking:
1. Query: "Are there any existing bookings that overlap with this time?"
2. If yes → Reject with error: "Sorry, this slot was just booked."
3. If no → Create the booking within a database transaction

The transaction ensures atomicity—only ONE booking succeeds.
```

**Database constraint:**
```sql
-- Prevents overlapping bookings for the same user
CREATE UNIQUE INDEX idx_no_overlapping_bookings 
ON bookings (user_id, starts_at) 
WHERE status = 'scheduled';
```

**User experience:**
- Client A submits first (2:01:30.001) → Success
- Client B submits second (2:01:30.002) → Error message: "This time was just booked. Please choose another time."
- Client B returns to calendar, sees 3:00pm now grayed out
- Client B picks 3:30pm instead

**Why this works:**
- Database-level constraint guarantees only one booking succeeds
- Error message is rare (only happens if two people submit at nearly the exact same moment)
- Most of the time, real-time updates (via WebSocket) prevent this scenario

### Solution 2: Soft Locking with Expiration

**More complex, use only if optimistic locking causes too many conflicts.**

**How it works:**

1. When client clicks a slot → create a temporary "lock" for 5 minutes
   ```
   SlotLock {
     user_id: professional's ID
     slot_time: "2024-05-13 15:00:00 UTC"
     locked_by_session: "session_abc123"
     expires_at: NOW() + 5 minutes
   }
   ```

2. While filling out form, periodically refresh the lock (every 30 seconds)

3. Other clients seeing the calendar see this slot as "unavailable" (grayed out)

4. If client abandons form → lock expires after 5 minutes → slot becomes available again

5. When client submits booking:
    - Check that their session still holds the lock
    - If yes → create booking, delete lock
    - If no → error "Lock expired, please select again"

**Pros:**
- Eliminates race conditions
- Provides better user experience (no "slot just taken" errors)

**Cons:**
- More complex
- If client opens form but doesn't book, slot is blocked for 5 minutes
- Requires periodic lock refresh (more server requests)

**Recommendation:** Start with optimistic locking. Only add soft locking if you see frequent conflicts in production.

---

## Timezone Handling

**Most error-prone part of booking systems. Must be PERFECT.**

### The Four Timezones

1. **Professional's timezone**
    - Stored in user profile: `user.timezone = "America/New_York"`
    - All availability is defined in this timezone
    - Example: "Monday 9am-5pm" means 9am-5pm Eastern time

2. **Client's timezone**
    - Auto-detected from browser: `Intl.DateTimeFormat().resolvedOptions().timeZone`
    - Example: Client in London → `"Europe/London"`
    - All displayed times are converted to this timezone

3. **UTC (Universal Time)**
    - All datetimes stored in database are in UTC
    - Example: A booking at "3pm EST" is stored as "20:00 UTC" (3pm EST = 8pm UTC)
    - WHY: Makes queries and calculations timezone-independent

4. **Display timezone** (same as client's timezone)
    - When showing times to the client
    - Example: Professional in NYC, client in Tokyo
        - Professional's 2pm EST = client's 3am JST next day
        - Display to client: "Wednesday, May 14, 3:00 AM"

### The Golden Rules

1. **ALWAYS store datetimes in UTC**
   ```
   Do: starts_at = "2024-05-13 20:00:00 UTC"
   Don't: starts_at = "2024-05-13 15:00:00" (ambiguous!)
   ```

2. **Convert to timezone only for display**
   ```
   // Store
   booking.starts_at = Time.parse("2024-05-13 15:00:00 EST").utc
   # => "2024-05-13 20:00:00 UTC"

   // Display
   booking.starts_at.in_time_zone("Europe/London")
   # => "2024-05-13 21:00:00 BST" (9pm British Summer Time)
   ```

3. **When calculating availability, always work in professional's timezone or UTC**
    - Professional says "I'm available Monday 9am-5pm"
    - This means Monday 9am-5pm in THEIR timezone (stored in user.timezone)
    - Convert to UTC for database queries
    - Convert to client's timezone for display only

### Example: Complete Timezone Flow

**Setup:**
- Professional: Alice in New York (America/New_York, UTC-5 in winter, UTC-4 in summer DST)
- Client: Bob in London (Europe/London, UTC+0 in winter, UTC+1 in summer BST)
- Current date: May 13, 2024 (DST active in both locations)

**Alice's availability:**
```
Monday: 9:00 AM - 5:00 PM (her time)
```

**Step 1: Generate slots in Alice's timezone**
```
Monday, May 13, 2024
9:00 AM, 9:30 AM, 10:00 AM, ..., 4:30 PM
(All in America/New_York timezone)
```

**Step 2: Convert to UTC for storage**
```
9:00 AM EDT (May 13) = 1:00 PM UTC (May 13)
4:30 PM EDT (May 13) = 8:30 PM UTC (May 13)
```

**Step 3: Display to Bob in London time**
```
1:00 PM UTC = 2:00 PM BST (British Summer Time)
8:30 PM UTC = 9:30 PM BST

Bob sees slots:
2:00 PM, 2:30 PM, 3:00 PM, ..., 9:30 PM
(All on Monday, May 13, in his local time)
```

**Step 4: Bob books 7:00 PM BST**

**What this means in different timezones:**
- Bob's perspective: Monday 7:00 PM (London time)
- Database storage: Monday 6:00 PM UTC
- Alice's perspective: Monday 2:00 PM (New York time)

**Confirmation emails:**
- Bob's email: "Your meeting is scheduled for Monday, May 13 at 7:00 PM BST"
- Alice's email: "New booking: Monday, May 13 at 2:00 PM EDT with Bob"

### Daylight Saving Time (DST) Handling

**The problem:**
- Professional sets "Monday 9am-5pm" recurring availability
- In March, clocks "spring forward" (lose an hour)
- In November, clocks "fall back" (gain an hour)
- How do we handle bookings across DST transitions?

**The solution:**
- Availability times are stored as "wall clock" times (9am is always 9am in the professional's timezone)
- When DST changes, the UTC offset changes, but the availability stays "9am" in local time
- Database stores availability as TIME (not TIMESTAMP), so it's DST-agnostic

**Example:**
```
Professional's availability: Monday 9am-5pm America/New_York

On March 10 (before DST):
9am EST = 2pm UTC

On March 11 (after DST spring forward):
9am EDT = 1pm UTC (one hour earlier in UTC!)

But the professional's availability is still "9am"—
the system automatically adjusts the UTC conversion.
```

**Key insight:** The professional thinks in "wall clock time" (9am is 9am), not UTC offsets. The system handles the UTC math automatically.

### Client Timezone Detection

**On first page load:**
```javascript
// JavaScript in browser
const clientTimezone = Intl.DateTimeFormat().resolvedOptions().timeZone;
// Example: "Europe/London"

// Send to server (via hidden form field or cookie)
```

**Server stores temporarily (in session) and uses for all time displays**

**What if detection fails?**
- Fallback to IP-based geolocation
- If that fails, default to UTC and show a timezone picker
- Always show timezone name on confirmation: "All times shown in Europe/London time"

---

## Cancellation & Rescheduling

### Cancellation Logic

**Who can cancel:**
1. Client (via magic link in email)
2. Professional (from dashboard)

**Business rules:**

1. **Cancellation window:**
    - Free plan: Can cancel up to 24 hours before meeting
    - Paid plans: Can cancel up to 2 hours before meeting
    - Why: Prevents last-minute cancellations that waste the professional's time

2. **No-show policy:**
    - If client doesn't show up, professional can mark as "no-show" in dashboard
    - This is tracked for analytics but doesn't affect future bookings (yet)
    - Future feature: Block repeat no-show clients

**Cancellation flow (Client):**

1. Client clicks "Cancel Booking" link in email
   ```
   URL: https://smooth.com/bookings/123/cancel?token=abc123...
   ```

2. Lands on cancellation page:
    - Shows booking details (date, time, professional)
    - "Are you sure you want to cancel?"
    - [Cancel Booking] button
    - Textarea for optional reason

3. Clicks "Cancel Booking"

4. System validates:
    - Token matches booking
    - Booking status is "scheduled" (can't cancel if already cancelled)
    - Within cancellation window (e.g., more than 2 hours before meeting)

5. If valid:
    - Update booking status to "cancelled"
    - Send email to professional: "Booking cancelled: [Client name] on [date] at [time]"
    - Send confirmation email to client: "Your booking has been cancelled"
    - Free up the time slot (other clients can now book it)

6. Show confirmation: "Booking cancelled successfully"

**Cancellation flow (Professional):**

1. Professional views booking in dashboard
2. Clicks "Cancel" button next to booking
3. Confirmation dialog: "Cancel this booking with [Client name]?"
4. Optional: Select reason (dropdown: "No longer available", "Client requested", "Other")
5. Clicks "Confirm"
6. System:
    - Updates booking status to "cancelled"
    - Sends email to client: "Your booking on [date] at [time] has been cancelled by [Professional name]"
    - Frees up the slot

### Rescheduling Logic

**Who can reschedule:**
- Client only (via magic link in email)
- Professional cannot reschedule on client's behalf (can only cancel and ask client to rebook)

**Why:** Rescheduling requires the client to pick a new time that works for THEM. The professional doesn't know the client's availability.

**Reschedule flow:**

1. Client clicks "Reschedule" link in email
   ```
   URL: https://smooth.com/bookings/123/reschedule?token=xyz789...
   ```

2. Lands on reschedule page:
    - Shows current booking details (date, time)
    - Calendar widget appears (same as original booking page)
    - Shows available slots (excluding the currently booked slot)

3. Client selects new time

4. System validates:
    - Token matches booking
    - Booking status is "scheduled"
    - New time is available (recheck for conflicts)
    - Within reschedule window (e.g., must reschedule at least 2 hours before ORIGINAL meeting time)

5. If valid:
    - Update booking:
      ```
      old_starts_at = current starts_at (for records)
      starts_at = new selected time
      ends_at = new time + duration
      ```
    - Send email to client: "Booking rescheduled from [old time] to [new time]"
    - Send email to professional: "[Client name] rescheduled from [old time] to [new time]"

6. Show confirmation with updated details

**Reschedule limit:**
- Free plan: Can reschedule once per booking
- Paid plans: Can reschedule up to 2 times per booking
- Why: Prevents clients from endlessly rescheduling

---

## Notification & Reminder System

### Email Types

#### 1. Booking Confirmation (Both Parties)

**Sent:** Immediately after booking is created

**To Client:**
```
Subject: Booking Confirmed with [Professional Name]

Hi [Client Name],

Your booking is confirmed!

📅 Date: [Day], [Date]
🕐 Time: [Time] ([Client Timezone])
⏱ Duration: [Duration] minutes
👤 With: [Professional Name]

Your message: "[Optional message from booking form]"

A calendar invite is attached to this email.

Need to change plans?
[Reschedule] [Cancel Booking]

Thanks,
The Smooth Team
```

**To Professional:**
```
Subject: New Booking: [Client Name] on [Date] at [Time]

Hi [Professional Name],

You have a new booking!

👤 Attendee: [Client Name] ([Client Email])
📅 Date: [Date]
🕐 Time: [Time] ([Your Timezone])
⏱ Duration: [Duration]

Message from attendee:
"[Optional message]"

[View in Dashboard] [Cancel This Booking]

Thanks,
Smooth
```

**Email includes .ics calendar invite attachment** (so both parties can add to their calendar with one click)

#### 2. Reminder Email (Both Parties)

**Sent:** 1 hour before meeting (configurable per professional: 15min, 30min, 1hr, 2hrs, 24hrs)

**To Client:**
```
Subject: Reminder: Meeting with [Professional Name] in 1 Hour

Hi [Client Name],

Friendly reminder—your meeting is coming up soon!

🕐 In 1 hour: [Time] ([Client Timezone])
👤 With: [Professional Name]

Need to cancel or reschedule?
[Reschedule] [Cancel]

See you soon!
```

**To Professional:**
```
Subject: Reminder: Meeting with [Client Name] in 1 Hour

Hi [Professional Name],

Upcoming meeting reminder:

🕐 In 1 hour: [Time]
👤 With: [Client Name]

[View Details]
```

#### 3. Cancellation Confirmation

**Sent:** Immediately after cancellation

**To Client:**
```
Subject: Booking Cancelled

Hi [Client Name],

Your booking on [Date] at [Time] has been cancelled.

[Reason: if provided]

Want to reschedule? [Book Again]
```

**To Professional:**
```
Subject: Booking Cancelled: [Client Name]

Hi [Professional Name],

[Client Name] cancelled their booking:
📅 [Date] at [Time]
[Reason: if provided]

This time slot is now available for other bookings.
```

#### 4. Reschedule Confirmation

**To Client:**
```
Subject: Booking Rescheduled

Hi [Client Name],

Your booking has been rescheduled!

Was: [Old Date] at [Old Time]
Now: [New Date] at [New Time]

A new calendar invite is attached.

[View Details]
```

**To Professional:**
```
Subject: Booking Rescheduled: [Client Name]

Hi [Professional Name],

[Client Name] rescheduled their booking:

Was: [Old Date] at [Old Time]
Now: [New Date] at [New Time]

[View in Dashboard]
```

### When Emails Are Queued

All emails are sent via **background jobs** (not inline during request) to keep the booking process fast.

**Email job priorities:**
- High: Confirmation emails (processed within 30 seconds)
- Medium: Reminder emails (exact timing matters)
- Low: Summary/digest emails (can be delayed)

### Reminder Scheduling Logic

**When booking is created:**
```
if starts_at > NOW + reminder_window
  schedule_reminder_job(booking.id, send_at: starts_at - 1.hour)
end
```

**Example:**
- Booking created: Monday 2:00pm
- Meeting time: Wednesday 3:00pm
- Reminder time: Wednesday 2:00pm (1 hour before)
- Job scheduled for: Wednesday 2:00pm

**What if meeting is rescheduled?**
- Cancel old reminder job
- Schedule new reminder job at new time

---

## User Roles & Permissions

### Professional (Account Holder)

**Can:**
- Create, edit, delete meeting types
- Set weekly availability schedule
- Add/remove blocked dates
- View all their bookings (past and future)
- Cancel bookings
- Export bookings to CSV
- Update profile (name, bio, photo)
- Change username (if new username is available)
- Change timezone
- Upgrade/downgrade subscription plan
- Delete account (cancels all future bookings and deletes all data)

**Cannot:**
- View other professionals' bookings
- Book on their own booking page (would create self-booking, which is allowed but weird)
- Reschedule a booking (only cancel and ask client to rebook)

### Client (No Account)

**Can:**
- View any professional's public booking page
- Book available slots
- Cancel their bookings (via magic link)
- Reschedule their bookings (via magic link)
- Download calendar invite

**Cannot:**
- Log in (no account system for clients)
- View bookings they made in the past (unless they save the magic links)
- Change professional's availability
- See other clients' bookings

### System Admin (Future)

**Can:**
- View all professionals
- View all bookings
- Suspend/unsuspend accounts
- Handle billing issues
- Send manual emails
- View analytics across all users

**Cannot:**
- Impersonate users
- View private messages
- Change bookings without logging the action

---

## Business Rules & Constraints

### Account & Username Rules

1. **Username constraints:**
    - 3-30 characters
    - Letters, numbers, hyphens only
    - Must start with a letter
    - Case-insensitive (Alice = alice = ALICE)
    - Cannot be changed more than once per 30 days
    - Reserved usernames: admin, api, support, help, about, pricing, etc.

2. **Email:**
    - Must be verified before account is fully active
    - One account per email
    - If user deletes account, email can be reused after 90 days

3. **Account deletion:**
    - All future bookings are auto-cancelled
    - Clients are notified
    - Data is soft-deleted (marked deleted but not removed for 90 days)
    - After 90 days, hard delete from database

### Meeting Type Rules

1. **Duration options:**
    - 15, 30, 45, 60, 90, 120 minutes
    - Cannot be longer than 3 hours (business rule: keeps meetings manageable)

2. **Buffer time options:**
    - 0, 5, 10, 15, 30 minutes
    - Cannot be longer than the meeting duration

3. **Minimum one meeting type:**
    - Professional must have at least one active meeting type
    - Cannot delete last meeting type
    - Cannot deactivate all meeting types (booking page would be empty)

### Availability Rules

1. **Slot constraints:**
    - Cannot start before 12:00 AM (midnight)
    - Cannot end after 11:59 PM
    - Start time must be before end time
    - Cannot overlap on the same day

2. **Total hours per week:**
    - Free plan: Up to 40 hours/week
    - Paid plans: Unlimited
    - Why: Prevents abuse (someone setting available 24/7)

3. **Minimum slot duration:**
    - Must be at least as long as the shortest meeting type
    - Example: If you offer 60-minute meetings, availability slot must be at least 60 minutes

### Booking Rules

1. **Booking window:**
    - Minimum advance notice: 30 minutes to 48 hours (configurable)
    - Default: 2 hours
    - Maximum advance: 7 to 365 days (configurable)
    - Default: 60 days

2. **Duplicate prevention:**
    - Same email cannot book overlapping slots with same professional
    - Example: Cannot book 3pm and 3:30pm on the same day

3. **Concurrent bookings limit:**
    - Free plan: Up to 50 active bookings at once
    - Paid plans: Unlimited
    - Why: Prevents spam/abuse

### Cancellation Rules

1. **Cancellation window:**
    - Free plan: Must cancel at least 24 hours before meeting
    - Paid plans: Must cancel at least 2 hours before meeting
    - If within the window, can still cancel but professional is notified

2. **No refunds on cancellation:**
    - This rule applies to Phase 2 when payment collection is added
    - If client paid upfront, no refund if they cancel within 24 hours

### Plan Limits

#### Free Plan
- 1 meeting type
- 40 hours/week availability
- 50 active bookings
- Email notifications only
- Smooth branding on booking page
- Standard email templates

#### Starter Plan ($8/mo)
- 5 meeting types
- Unlimited availability hours
- Unlimited bookings
- Remove Smooth branding
- Custom booking page colors
- Calendar integration (Google Cal)
- 1-hour cancellation window

#### Pro Plan ($15/mo)
- Unlimited meeting types
- Team scheduling (Round-robin, collective)
- Payment collection (Stripe)
- Video call integration (Zoom, Meet)
- Custom domain (book.yourdomain.com)
- Webhooks & API access
- Priority support
- 30-minute cancellation window

---

## Edge Cases & Solutions

### Edge Case 1: Timezone Confusion

**Problem:** Professional in NYC sets "Monday 9am-5pm" availability. Client in Sydney books "Monday 10am". Is that Monday 10am Sydney time or NYC time?

**Solution:**
- All availability is defined in professional's timezone
- Client sees times converted to THEIR timezone
- Confirmation email shows time in BOTH timezones:
  ```
  Your Time: Monday, May 13 at 10:00 AM AEST
  [Professional Name]'s Time: Sunday, May 12 at 8:00 PM EDT
  ```

### Edge Case 2: Client Books Then Leaves Page

**Problem:** Client selects a slot, form appears, client closes browser without submitting. Is the slot locked?

**Solution (with optimistic locking):**
- No locking → slot is still available
- If another client books it, first client gets an error on submit

**Solution (with soft locking):**
- Slot is locked for 5 minutes
- Lock expires → slot becomes available again
- Client who abandoned gets no email (they never completed booking)

### Edge Case 3: Professional Changes Availability While Client Books

**Problem:**
1. Professional's availability: Monday 9am-5pm
2. Client starts booking Monday 3pm slot
3. Professional changes availability: Monday 9am-12pm (removes afternoon)
4. Client submits booking for 3pm

**Solution:**
- At submit time, system recalculates available slots
- 3pm is no longer available → booking fails
- Client sees error: "Availability has changed. Please select a new time."
- Calendar refreshes to show updated availability

### Edge Case 4: Daylight Saving Time Transition

**Problem:** Professional has a booking at "2:30 AM" on the day DST "springs forward" (that hour doesn't exist).

**Solution:**
- Booking system should prevent booking during the "missing hour"
- When generating slots, skip 2:00 AM - 3:00 AM on DST spring-forward days
- Professional can still set availability "12am-6am" but system automatically skips the missing hour

### Edge Case 5: Client Reschedules to a Worse Time for Professional

**Problem:** Client booked Friday 3pm. Reschedules to Friday 9pm. Professional prefers afternoon meetings.

**Solution:**
- If slot is available, reschedule is allowed (professional defined 9pm as available)
- Professional can remove 9pm from availability to prevent future bookings at that time
- Professional can contact client to request a different time (outside system)

### Edge Case 6: Professional Deletes Account With Future Bookings

**Problem:** Professional has 10 bookings scheduled next week. Deletes their account.

**Solution:**
- System asks: "You have X upcoming bookings. Deleting your account will cancel all of them. Are you sure?"
- If confirmed:
    - All future bookings are marked "cancelled"
    - Clients receive cancellation emails: "Unfortunately, [Professional Name] is no longer available..."
    - Booking page shows "This page is no longer active"

### Edge Case 7: Two Clients Submit at Exact Same Time

**Problem:** Covered in Conflict Prevention section. Database constraint ensures only one succeeds.

### Edge Case 8: Professional Timezone Changes During Active Bookings

**Problem:**
- Professional in NYC (EST)
- Booking scheduled: Monday 3pm EST
- Professional moves to California, changes timezone to PST
- What time is the meeting now?

**Solution:**
- Booking times are stored in UTC (immutable)
- Stored: "Monday 8pm UTC"
- Display to professional changes:
    - Was: "Monday 3pm EST"
    - Now: "Monday 12pm PST"
- Booking time didn't change—only the display changed
- Client's email still shows correct time in their timezone

### Edge Case 9: Meeting Spans Midnight

**Problem:** Professional's availability: "Monday 11:00 PM - Tuesday 1:00 AM" (night shift worker)

**Solution:**
- System handles this with datetime ranges, not day-based logic
- Booking at 11:30pm Monday is stored as "Monday 11:30pm - Tuesday 12:00am"
- Works correctly as long as end time is after start time

### Edge Case 10: Client's Timezone Changes Between Booking and Meeting

**Problem:**
- Client in NYC books Monday 3pm (their local time)
- Client flies to Tokyo before the meeting
- Confirmation email said "Monday 3pm EST" (their timezone at booking)
- Meeting is actually Tuesday 4am JST (their current timezone)

**Solution:**
- Calendar invite (.ics file) contains time in UTC
- Client's calendar app automatically converts to their current timezone
- System cannot know client moved → this is a limitation
- Best practice: Include both professional's and client's timezone in all emails
  ```
  Your booking:
  Your time (at booking): Monday, May 13 at 3:00 PM EDT
  [Professional]'s time: Monday, May 13 at 3:00 PM EDT
  
  (If your timezone has changed, please check your calendar app)
  ```

---

## Monetization Logic

### Pricing Tiers

#### Free (Forever)
- **Target:** Individuals trying out the product
- **Revenue:** $0/mo
- **Limits:**
    - 1 meeting type
    - Up to 50 active bookings
    - 40 hours/week max availability
    - Smooth branding on booking page
- **Goal:** Convert to Starter after they hit limits

#### Starter ($8/mo)
- **Target:** Freelancers, solopreneurs, small business owners
- **Revenue:** $8/mo
- **Includes:**
    - 5 meeting types
    - Unlimited bookings
    - Unlimited availability hours
    - Remove Smooth branding
    - Custom colors
    - Google Calendar sync
    - 1-hour cancellation window
- **Goal:** This is the primary revenue tier (80% of paying customers)

#### Pro ($15/mo)
- **Target:** Teams, agencies, consultants with higher needs
- **Revenue:** $15/mo
- **Includes:**
    - Everything in Starter
    - Unlimited meeting types
    - Team scheduling
    - Stripe payment collection
    - Zoom/Meet auto-integration
    - Custom domain (book.yourdomain.com)
    - API access & webhooks
    - Priority support
- **Goal:** Upsell power users (20% of paying customers)

### Revenue Math

**Target: $1,000 MRR**

**Mix:**
- 100 Starter customers × $8 = $800
- 13 Pro customers × $15 = $195
- **Total: ~$995 MRR**

**To reach $1k MRR:**
- Need ~113 paying customers total
- Assume 20% conversion from Free → Paid
- Need ~565 total signups

**Churn assumptions:**
- Monthly churn: 5% (industry average for this tier)
- Annual retention: 60% (need to replace 40% each year)

### Monetization Triggers

**When to show upgrade prompts:**

1. **Hitting limits (Free plan):**
    - User tries to create 2nd meeting type → "Upgrade to Starter for 5 meeting types"
    - User hits 50 active bookings → "Upgrade to Starter for unlimited bookings"
    - User tries to set 50+ hours/week → "Upgrade to remove this limit"

2. **Feature access (Starter → Pro):**
    - User clicks "Collect Payment" → "Upgrade to Pro to accept payments"
    - User clicks "Add Team Member" → "Upgrade to Pro for team scheduling"
    - User clicks "Connect Custom Domain" → "Pro feature"

3. **Soft prompts:**
    - After 10 bookings: "You're getting popular! Upgrade to remove Smooth branding."
    - After 30 days free: "Loving Smooth? Upgrade to unlock unlimited meeting types."

### Payment Flow (Stripe)

1. User clicks "Upgrade to Starter"
2. Redirected to Stripe Checkout (hosted payment page)
3. Enter credit card details
4. Stripe processes payment
5. Webhook sent to Smooth: "Payment successful"
6. Smooth updates user record:
   ```
   user.plan = "starter"
   user.stripe_customer_id = "cus_abc123"
   user.subscription_id = "sub_xyz789"
   ```
7. User redirected back to dashboard
8. Success message: "You're now on the Starter plan!"

---

## Summary: Core Value Props

### For Professionals
1. **Time saved:** 2-3 hours/week not coordinating schedules
2. **Professionalism:** Dedicated booking link looks more professional than email
3. **Control:** Set exact availability, buffer time, meeting types
4. **No-show reduction:** Calendar invites reduce no-shows by 50%

### For Clients
1. **Instant booking:** No waiting for email reply
2. **Transparency:** See all available times upfront
3. **Convenience:** Book at 11pm on a Sunday (when you remember)
4. **Timezone clarity:** See times in YOUR timezone automatically

### For Smooth (The Business)
1. **Network effects:** More bookings = more value = less churn
2. **Viral loop:** Every booking email is free advertising (client sees Smooth link)
3. **Upsell path:** Free → Starter → Pro → Team plan (future)
4. **Low support burden:** Self-service system, minimal support tickets

---

**END OF BUSINESS LOGIC DOCUMENT**

This document defines every rule, flow, and decision point in Smooth. Implementation details (code, database queries, UI) are separate—this is the "what" and "why", not the "how".
