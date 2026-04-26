export interface GlobalEntity {
  id: string;
  createdAt?: string;
  updatedAt?: string;
}

// --- Email / Account ---
export interface EmailMetadata {
  [key: string]: any;
}

export interface Email extends GlobalEntity {
  emailProviderId?: string;
  email: string;
  username?: string;
  password?: string;
  name?: string;
  recoveryEmail?: string;
  phoneNumber?: string;
  status: string;
  tags?: string[];
  lastUsedAt?: string;
  scheduledDeletionAt?: string;
  totpSecretKey?: string;
  backupCodes?: string;
  metadata?: EmailMetadata;

  // Relations
  services?: Service[];
  twoFactorMethods?: Email2FA[];
  recentActivity?: ActivityItem[];
}

// --- Service Provider ---
export interface ServiceProvider extends GlobalEntity {
  name: string;
  type: string; // 'website' | 'pc' | 'mobile' or custom
  category?: string;
  metadata?: any;
}

// --- Service ---
export interface ServiceMetadata {
  [key: string]: any;
}

export interface Service extends GlobalEntity {
  emailId?: string;
  serviceProviderId: string;
  linkedServiceId?: string;
  tags?: string[];
  categories?: string[];
  metadata?: ServiceMetadata;
  twoFactorMethods?: Service2FA[];
  secretKeys?: SecretKey[];
}

// --- 2FA ---
export type TwoFactorType = 'totp' | 'otp_phone' | 'recovery_email' | 'backup_code';

export interface Email2FA extends GlobalEntity {
  emailId: string;
  type: TwoFactorType;
  value: any;
}

export interface Service2FA extends GlobalEntity {
  serviceId: string;
  type: TwoFactorType;
  value: any;
}

// --- Secret Key ---
export interface SecretKey extends GlobalEntity {
  serviceId: string;
  key: string;
  value: string;
  active?: boolean;
}

// --- Proxy ---
export type ProxyType = 'private' | 'shared';
export type ProxySourceType = 'datacenter' | 'residential' | 'mobile';
export type ProxyRotationType = 'static' | 'rotating';
export type ProxyPricingType = 'time' | 'bandwidth';
export type ProxyProtocol = 'http' | 'https' | 'socks5';
export type ProxyStatus = 'active' | 'expired' | 'disabled';

export interface Proxy extends GlobalEntity {
  ipVersion: number;
  proxyType: ProxyType;
  sourceType: ProxySourceType;
  rotationType: ProxyRotationType;
  pricingType: ProxyPricingType;
  protocol?: ProxyProtocol;
  host?: string;
  port?: number;
  username?: string;
  password?: string;
  country?: string;
  city?: string;
  isp?: string;
  durationDays?: number;
  bandwidthGb?: number;
  price?: number;
  status: ProxyStatus;
  metadata?: any;
}

// --- Reg (Registration) ---
export interface RegSession extends GlobalEntity {
  type: 'email' | 'service';
  emailProviderId?: string; // if type === 'email'
  serviceId?: string; // if type === 'service' (refers to ServiceProvider ID)
}

export interface RegAccountMetadata {
  username: string;
  password?: string;
  email?: string;
  emailId?: string;
  [key: string]: any;
}

export interface RegAccount extends GlobalEntity {
  regSessionId: string;
  agentId: string;
  userAgent: string;
  proxyId: string;
  status?: 'success' | 'failed' | 'processing'; // Keeping status as it's essential for state tracking
  metadata: RegAccountMetadata;
}

// --- Agent ---
export interface Fingerprint {
  canvas: string;
  audio: string;
  clientRect: string;
  webglImage: string;
  webglMetadata: string;
  webglVector: string;
  webglVendor: string;
  webglReRender: string;
}

export interface Agent extends GlobalEntity {
  name: string;
  userAgent: string;
  os: string;
  timezone?: string;
  resolution?: string;
  webrtc?: string;
  location?: string;
  language?: string;
  fingerprint?: Fingerprint;
}

// --- Activity ---
export interface ActivityItem extends GlobalEntity {
  emailId: string;
  action: 'login' | 'security_change' | 'data_export' | 'device_linked';
  device: string;
  location: string;
  status: 'success' | 'warning' | 'failed';
  timestamp: string; // duplicate of createdAt usually?
}

// --- Cookie ---
export interface Cookie {
  name: string;
  value: string;
  domain: string;
  path: string;
  expires?: number;
  httpOnly: boolean;
  secure: boolean;
}
