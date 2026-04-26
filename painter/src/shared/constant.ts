export interface EmailProviderConfig {
  id: string;
  provider: string; // name/label
  websiteUrl: string; // for favicon
  emailSuffix: string; // for identification
}

export const EMAIL_PROVIDERS: EmailProviderConfig[] = [
  {
    id: 'google',
    provider: 'Google',
    websiteUrl: 'https://google.com',
    emailSuffix: '@gmail.com',
  },
  {
    id: 'apple',
    provider: 'Apple',
    websiteUrl: 'https://apple.com',
    emailSuffix: '@icloud.com',
  },
];

export const EMAIL_SERVICE_CATEGORIES: string[] = [
  'social_media',
  'music',
  'entertainment',
  'productivity',
  'gaming',
  'shopping',
  'finance',
  'other',
];

export const DEFAULT_TAGS: string[] = [
  'work',
  'personal',
  'finance',
  'social_media',
  'important',
  'archive',
  'shopping',
  'gaming',
  'entertainment',
  'productivity',
];
