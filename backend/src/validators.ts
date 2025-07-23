const USERNAME_REGEX = /^[a-zA-Z0-9_]{3,30}$/;
const DATE_REGEX = /^\d{4}-\d{2}-\d{2}$/;
const MAX_REQUESTS_PER_DAY = 10000;
const MAX_BULK_UPLOAD_DAYS = 365;

export function validateUsername(username: string): string | null {
  if (!username || typeof username !== 'string') {
    return 'Username is required';
  }
  
  if (!USERNAME_REGEX.test(username)) {
    return 'Username must be 3-30 characters and contain only letters, numbers, and underscores';
  }
  
  return null;
}

export function validateDeviceId(deviceId: string): string | null {
  if (!deviceId || typeof deviceId !== 'string') {
    return 'Device ID is required';
  }
  
  if (deviceId.length !== 36) {
    return 'Invalid device ID format';
  }
  
  return null;
}

export function validateDate(date: string): string | null {
  if (!DATE_REGEX.test(date)) {
    return 'Invalid date format. Use YYYY-MM-DD';
  }
  
  const dateObj = new Date(date);
  const today = new Date();
  today.setHours(23, 59, 59, 999);
  
  if (dateObj > today) {
    return 'Cannot upload data for future dates';
  }
  
  return null;
}

export function validateUsageData(data: any): string | null {
  if (typeof data.totalRequests !== 'number' || data.totalRequests < 0) {
    return 'Total requests must be a non-negative number';
  }
  
  if (data.totalRequests > MAX_REQUESTS_PER_DAY) {
    return `Total requests cannot exceed ${MAX_REQUESTS_PER_DAY} per day`;
  }
  
  if (typeof data.totalInputTokens !== 'number' || data.totalInputTokens < 0) {
    return 'Total input tokens must be a non-negative number';
  }
  
  if (typeof data.totalOutputTokens !== 'number' || data.totalOutputTokens < 0) {
    return 'Total output tokens must be a non-negative number';
  }
  
  if (typeof data.totalCost !== 'number' || data.totalCost < 0) {
    return 'Total cost must be a non-negative number';
  }
  
  return null;
}

export function validateBulkUpload(dailyUsage: any[]): string[] {
  const errors: string[] = [];
  
  if (!Array.isArray(dailyUsage)) {
    return ['Daily usage must be an array'];
  }
  
  if (dailyUsage.length === 0) {
    return ['No usage data provided'];
  }
  
  if (dailyUsage.length > MAX_BULK_UPLOAD_DAYS) {
    return [`Cannot upload more than ${MAX_BULK_UPLOAD_DAYS} days at once`];
  }
  
  const seenDates = new Set<string>();
  
  dailyUsage.forEach((entry, index) => {
    const dateError = validateDate(entry.date);
    if (dateError) {
      errors.push(`Entry ${index}: ${dateError}`);
      return;
    }
    
    if (seenDates.has(entry.date)) {
      errors.push(`Entry ${index}: Duplicate date ${entry.date}`);
    }
    seenDates.add(entry.date);
    
    const usageError = validateUsageData(entry);
    if (usageError) {
      errors.push(`Entry ${index}: ${usageError}`);
    }
  });
  
  return errors;
}