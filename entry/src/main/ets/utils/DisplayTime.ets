function pad(value: number): string {
  return value < 10 ? '0' + value.toString() : value.toString();
}

function validSeconds(seconds: number): boolean {
  return Number.isFinite(seconds) && seconds > 0;
}

export function formatDate(seconds: number): string {
  if (!validSeconds(seconds)) { return ''; }
  const value: Date = new Date(seconds * 1000);
  return value.getFullYear().toString() + '-' + pad(value.getMonth() + 1) + '-' + pad(value.getDate());
}

export function formatDateTime(seconds: number): string {
  if (!validSeconds(seconds)) { return ''; }
  const value: Date = new Date(seconds * 1000);
  return formatDate(seconds) + ' ' + pad(value.getHours()) + ':' + pad(value.getMinutes());
}
