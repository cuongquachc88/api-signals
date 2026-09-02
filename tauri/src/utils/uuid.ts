export function uuid(): string {
  return crypto.randomUUID();
}

export function newKeyValue(key = '', value = '') {
  return { id: uuid(), key, value, enabled: true, description: null };
}
