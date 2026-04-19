// data/utils/date_today.js
// Note: This uses the machine date where Maestro runs (not necessarily the device date).
const now = new Date();

const pad2 = (n) => String(n).padStart(2, "0");

output.date_today = {
  year: String(now.getFullYear()),
  month: pad2(now.getMonth() + 1),
  day: pad2(now.getDate()),
  dayOfMonth: String(now.getDate()),
  iso: `${now.getFullYear()}-${pad2(now.getMonth() + 1)}-${pad2(now.getDate())}`,
};

