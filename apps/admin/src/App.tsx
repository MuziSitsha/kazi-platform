import { FormEvent, useEffect, useMemo, useState } from 'react';

type PlatformSettings = {
  defaultCommissionRate: number;
  cashPaymentsEnabled: boolean;
  cardPaymentsEnabled: boolean;
  walletPaymentsEnabled: boolean;
  instantBookingsEnabled: boolean;
  scheduledBookingsEnabled: boolean;
  businessLegalName?: string;
  payoutBankName?: string;
  payoutAccountHolder?: string;
  payoutAccountNumber?: string;
  payoutAccountType?: string;
  payoutBranchCode?: string;
  payoutReference?: string;
};

type ProviderDocument = {
  id: string;
  documentType: string;
  fileName: string;
  fileUrl?: string;
  status: 'submitted' | 'approved' | 'rejected';
  reviewNote?: string;
  createdAt: string;
};

type PendingProvider = {
  userId: string;
  serviceArea?: string;
  yearsExperience?: number;
  verificationStatus: 'pending' | 'approved' | 'rejected';
  documentsSubmitted: boolean;
  user?: {
    firstName?: string;
    lastName?: string;
    phone: string;
    email?: string;
  };
  documents: ProviderDocument[];
};

type DashboardMetrics = {
  customerCount: number;
  providerCount: number;
  pendingVerifications: number;
  activeBookings: number;
  scheduledBookings: number;
  completedBookings: number;
  paidTransactions: number;
  grossMerchandiseValueCents: number;
  providerPayoutsCents: number;
  averageRating: number;
};

type RecentPayment = {
  id: string;
  bookingId: string;
  bookingRef?: string;
  paymentMethod: string;
  status: 'pending' | 'paid' | 'failed' | 'refunded';
  amountCents: number;
  commissionCents: number;
  providerEarningsCents: number;
  checkoutUrl?: string;
  updatedAt: string;
};

type AdminAuthResponse = {
  accessToken: string;
  refreshToken: string;
  user: {
    email?: string;
    firstName?: string;
    lastName?: string;
  };
};

const STAGING_HTTPS_API_BASE_URL = 'https://d1v0xfe0nj4abg.cloudfront.net/api/v1';

function resolveDefaultApiBaseUrl() {
  const configured = import.meta.env.VITE_API_BASE_URL;
  if (configured) {
    return configured;
  }

  const hostname = window.location.hostname;
  const isLocalHost = hostname === 'localhost' || hostname === '127.0.0.1';
  if (isLocalHost) {
    return 'http://127.0.0.1:3001/api/v1';
  }

  return STAGING_HTTPS_API_BASE_URL;
}

const DEFAULT_API_BASE_URL = resolveDefaultApiBaseUrl();

function getInitialApiBaseUrl() {
  const stored = localStorage.getItem('kazi.admin.apiBaseUrl');
  const onSecurePage = window.location.protocol === 'https:';
  const hostname = window.location.hostname;
  const isLocalHost = hostname === 'localhost' || hostname === '127.0.0.1';

  if (
    !stored
    || stored === 'http://localhost:3001/api/v1'
    || stored === 'http://127.0.0.1:3001/api/v1'
    || (onSecurePage && stored.startsWith('http://'))
    || (!isLocalHost && stored.includes('127.0.0.1'))
    || (!isLocalHost && stored.includes('localhost'))
  ) {
    return DEFAULT_API_BASE_URL;
  }

  return stored;
}

export function App() {
  const [apiBaseUrl, setApiBaseUrl] = useState(getInitialApiBaseUrl);
  const [email, setEmail] = useState(() => localStorage.getItem('kazi.admin.email') || '');
  const [password, setPassword] = useState('');
  const [token, setToken] = useState(() => localStorage.getItem('kazi.admin.token') || '');
  const [adminIdentity, setAdminIdentity] = useState(() => localStorage.getItem('kazi.admin.identity') || '');
  const [settings, setSettings] = useState<PlatformSettings | null>(null);
  const [metrics, setMetrics] = useState<DashboardMetrics | null>(null);
  const [recentPayments, setRecentPayments] = useState<RecentPayment[]>([]);
  const [pendingProviders, setPendingProviders] = useState<PendingProvider[]>([]);
  const [reviewNotes, setReviewNotes] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [savingSettings, setSavingSettings] = useState(false);
  const [statusMessage, setStatusMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState('');
  const [showDeveloperSettings, setShowDeveloperSettings] = useState(false);

  const payoutProfileReady = Boolean(
    settings?.businessLegalName?.trim()
      && settings.payoutBankName?.trim()
      && settings.payoutAccountHolder?.trim()
      && settings.payoutAccountNumber?.trim()
      && settings.payoutAccountType?.trim()
      && settings.payoutBranchCode?.trim(),
  );

  function formatCurrency(cents: number) {
    return new Intl.NumberFormat('en-ZA', {
      style: 'currency',
      currency: 'ZAR',
      maximumFractionDigits: 0,
    }).format(cents / 100);
  }

  const stats = useMemo(() => {
    const pendingCount = metrics?.pendingVerifications ?? pendingProviders.length;
    const documentCount = pendingProviders.reduce((count, provider) => count + provider.documents.length, 0);
    return [
      { label: 'Pending Reviews', value: String(pendingCount).padStart(2, '0'), detail: 'Provider verification queue' },
      { label: 'Documents Submitted', value: String(documentCount).padStart(2, '0'), detail: 'Files ready for compliance review' },
      {
        label: 'Gross Volume',
        value: metrics ? formatCurrency(metrics.grossMerchandiseValueCents) : '--',
        detail: 'All payment transactions on record',
      },
      {
        label: 'Provider Payouts',
        value: metrics ? formatCurrency(metrics.providerPayoutsCents) : '--',
        detail: 'Paid earnings booked to wallets',
      },
      {
        label: 'Paid Transactions',
        value: metrics ? String(metrics.paidTransactions).padStart(2, '0') : '--',
        detail: 'Confirmed card, EFT, wallet, and cash settlements',
      },
      {
        label: 'Avg Rating',
        value: metrics ? metrics.averageRating.toFixed(1) : '--',
        detail: 'Marketplace quality signal from reviews',
      },
      {
        label: 'Commission Rate',
        value: settings ? `${Math.round(settings.defaultCommissionRate * 100)}%` : '--',
        detail: 'Applied to newly created bookings',
      },
    ];
  }, [metrics, pendingProviders, settings]);

  useEffect(() => {
    localStorage.setItem('kazi.admin.apiBaseUrl', apiBaseUrl);
  }, [apiBaseUrl]);

  useEffect(() => {
    localStorage.setItem('kazi.admin.email', email);
  }, [email]);

  useEffect(() => {
    localStorage.setItem('kazi.admin.token', token);
  }, [token]);

  useEffect(() => {
    localStorage.setItem('kazi.admin.identity', adminIdentity);
  }, [adminIdentity]);

  useEffect(() => {
    if (!token.trim()) return;
    void loadDashboard();
  }, []);

  async function request<T>(path: string, init?: RequestInit, accessToken = token) {
    const response = await fetch(`${apiBaseUrl}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        ...(accessToken ? { Authorization: `Bearer ${accessToken}` } : {}),
        ...(init?.headers || {}),
      },
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(text || `Request failed with status ${response.status}`);
    }

    return response.json() as Promise<T>;
  }

  async function loginAdmin(event: FormEvent) {
    event.preventDefault();
    setLoading(true);
    setErrorMessage('');
    setStatusMessage('');

    try {
      const auth = await request<AdminAuthResponse>(
        '/auth/admin/login',
        {
          method: 'POST',
          body: JSON.stringify({ email, password }),
        },
        '',
      );

      const identity = auth.user.email || [auth.user.firstName, auth.user.lastName].filter(Boolean).join(' ') || 'Admin';
      setToken(auth.accessToken);
      setAdminIdentity(identity);
      setPassword('');
      await loadDashboard(undefined, auth.accessToken);
      setStatusMessage(`Signed in as ${identity}.`);
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to sign in as admin.');
    } finally {
      setLoading(false);
    }
  }

  async function loadDashboard(event?: FormEvent, accessToken = token) {
    event?.preventDefault();
    if (!accessToken.trim()) {
      setErrorMessage('Sign in as an admin before loading the dashboard.');
      return;
    }

    setLoading(true);
    setErrorMessage('');
    setStatusMessage('');

    try {
      const [settingsResponse, pendingResponse, metricsResponse, recentPaymentsResponse] = await Promise.all([
        request<PlatformSettings>('/admin/settings', undefined, accessToken),
        request<PendingProvider[]>('/admin/providers/pending-verification', undefined, accessToken),
        request<DashboardMetrics>('/admin/dashboard-metrics', undefined, accessToken),
        request<RecentPayment[]>('/admin/payments/recent', undefined, accessToken),
      ]);

      setSettings(settingsResponse);
      setPendingProviders(pendingResponse);
      setMetrics(metricsResponse);
      setRecentPayments(recentPaymentsResponse);
      setStatusMessage(adminIdentity ? `Admin console connected as ${adminIdentity}.` : 'Admin console connected.');
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to load admin dashboard.');
    } finally {
      setLoading(false);
    }
  }

  function signOut() {
    setToken('');
    setPassword('');
    setAdminIdentity('');
    setSettings(null);
    setMetrics(null);
    setRecentPayments([]);
    setPendingProviders([]);
    setStatusMessage('Signed out.');
    setErrorMessage('');
  }

  async function saveSettings() {
    if (!settings) return;
    setSavingSettings(true);
    setErrorMessage('');
    setStatusMessage('');

    try {
      const updatedSettings = await request<PlatformSettings>('/admin/settings', {
        method: 'PATCH',
        body: JSON.stringify(settings),
      });
      setSettings(updatedSettings);
      setStatusMessage('Platform settings updated.');
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to update settings.');
    } finally {
      setSavingSettings(false);
    }
  }

  async function reviewProvider(providerUserId: string, status: 'approved' | 'rejected') {
    setErrorMessage('');
    setStatusMessage('');

    try {
      await request(`/admin/providers/${providerUserId}/verification`, {
        method: 'PATCH',
        body: JSON.stringify({
          status,
          note: reviewNotes[providerUserId] || undefined,
        }),
      });

      setPendingProviders((current) => current.filter((provider) => provider.userId !== providerUserId));
      setStatusMessage(`Provider ${status === 'approved' ? 'approved' : 'rejected'} successfully.`);
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to review provider.');
    }
  }

  return (
    <main className="shell">
      <section className="hero">
        <div className="heroContent">
          <div className="brandLockup">
            <div className="brandMark">K</div>
            <div>
              <strong>KAZI</strong>
              <span>On-demand services · South Africa</span>
            </div>
          </div>
          <p className="eyebrow">KAZI Admin</p>
          <h1>Compliance, commission, and launch control for the South African MVP.</h1>
          <p className="lede">
            This console now runs the operational core of the MVP: platform policy, onboarding review,
            booking analytics, and payment monitoring for Johannesburg launch readiness.
          </p>
          <div className="heroPills">
            <span className="heroPill highlight">Johannesburg launch desk</span>
            <span className="heroPill">Provider compliance</span>
            <span className="heroPill">Payments monitoring</span>
          </div>
        </div>
        <div className="heroBadge">
          <span>af-south-1</span>
          <strong>Operations live</strong>
          <small>Local admin testing is preloaded.</small>
        </div>
      </section>

      <section className="authPanel surfacePanel">
        {token ? (
          <div className="authForm">
            <label>
              Signed in as
              <input value={adminIdentity || email} readOnly />
            </label>
            <div className="actionRow">
              <button type="button" className="secondaryButton" onClick={() => void loadDashboard()} disabled={loading}>
                {loading ? 'Refreshing...' : 'Refresh Dashboard'}
              </button>
              <button type="button" className="primaryButton" onClick={signOut}>
                Sign out
              </button>
            </div>
          </div>
        ) : (
          <form className="authForm" onSubmit={loginAdmin}>
            <label>
              Admin email address
              <input value={email} onChange={(event) => setEmail(event.target.value)} placeholder="Enter your admin email" type="email" autoComplete="username" />
            </label>
            <label>
              Password
              <input value={password} onChange={(event) => setPassword(event.target.value)} placeholder="Enter your password" type="password" autoComplete="current-password" />
            </label>
            <p className="authHint">Use your admin email and password to open the operations console.</p>
            <button type="submit" className="primaryButton" disabled={loading}>
              {loading ? 'Signing in...' : 'Sign in to Admin'}
            </button>
          </form>
        )}
        <div className="messageStack">
          <button type="button" className="secondaryButton" onClick={() => setShowDeveloperSettings((current) => !current)}>
            {showDeveloperSettings ? 'Hide developer settings' : 'Show developer settings'}
          </button>
          {showDeveloperSettings ? (
            <label>
              API Base URL
              <input value={apiBaseUrl} onChange={(event) => setApiBaseUrl(event.target.value)} placeholder={DEFAULT_API_BASE_URL} />
            </label>
          ) : null}
        </div>
        <div className="messageStack">
          {statusMessage ? <p className="statusOk">{statusMessage}</p> : null}
          {errorMessage ? <p className="statusError">{errorMessage}</p> : null}
        </div>
      </section>

      <section className="statsGrid">
        {stats.map((card) => (
          <article className="statCard" key={card.label}>
            <span>{card.label}</span>
            <strong>{card.value}</strong>
            <p>{card.detail}</p>
          </article>
        ))}
      </section>

      <section className="dashboardGrid">
        <article className="surfacePanel settingsPanel">
          <div className="sectionHeader">
            <div>
              <p className="eyebrow compact">Platform Settings</p>
              <h2>Commission, bookings, and payout controls</h2>
            </div>
            <button type="button" className="primaryButton" onClick={saveSettings} disabled={!settings || savingSettings}>
              {savingSettings ? 'Saving...' : 'Save Settings'}
            </button>
          </div>

          {settings ? (
            <div className="settingsForm">
              <div className="settingsGroup">
                <div>
                  <p className="eyebrow compact">Marketplace Policy</p>
                  <h3>Booking and payment rails</h3>
                </div>

                <label>
                  Default Commission Rate
                  <input
                    type="number"
                    step="0.01"
                    min="0"
                    max="0.5"
                    value={settings.defaultCommissionRate}
                    onChange={(event) => setSettings({ ...settings, defaultCommissionRate: Number(event.target.value) })}
                  />
                </label>

                <label className="toggleRow">
                  <input
                    type="checkbox"
                    checked={settings.cashPaymentsEnabled}
                    onChange={(event) => setSettings({ ...settings, cashPaymentsEnabled: event.target.checked })}
                  />
                  Cash payments enabled
                </label>

                <label className="toggleRow">
                  <input
                    type="checkbox"
                    checked={settings.cardPaymentsEnabled}
                    onChange={(event) => setSettings({ ...settings, cardPaymentsEnabled: event.target.checked })}
                  />
                  Card payments enabled
                </label>

                <label className="toggleRow">
                  <input
                    type="checkbox"
                    checked={settings.walletPaymentsEnabled}
                    onChange={(event) => setSettings({ ...settings, walletPaymentsEnabled: event.target.checked })}
                  />
                  Wallet payments enabled
                </label>

                <label className="toggleRow">
                  <input
                    type="checkbox"
                    checked={settings.instantBookingsEnabled}
                    onChange={(event) => setSettings({ ...settings, instantBookingsEnabled: event.target.checked })}
                  />
                  Instant bookings enabled
                </label>

                <label className="toggleRow">
                  <input
                    type="checkbox"
                    checked={settings.scheduledBookingsEnabled}
                    onChange={(event) => setSettings({ ...settings, scheduledBookingsEnabled: event.target.checked })}
                  />
                  Scheduled bookings enabled
                </label>
              </div>

              <div className="settingsGroup">
                <div className="settingsGroupHeader">
                  <div>
                    <p className="eyebrow compact">Business Payout Profile</p>
                    <h3>Where customer payments should land</h3>
                  </div>
                  <span className={`statusPill ${payoutProfileReady ? 'approved' : 'pending'}`}>
                    {payoutProfileReady ? 'Ready for settlement setup' : 'Banking details required'}
                  </span>
                </div>

                <p className="fieldHint">
                  Store the business banking profile here for settlement operations. Payment gateway keys still belong in secure server environment variables.
                </p>

                <div className="settingsGrid">
                  <label>
                    Business Legal Name
                    <input
                      type="text"
                      value={settings.businessLegalName || ''}
                      onChange={(event) => setSettings({ ...settings, businessLegalName: event.target.value })}
                    />
                  </label>

                  <label>
                    Bank Name
                    <input
                      type="text"
                      value={settings.payoutBankName || ''}
                      onChange={(event) => setSettings({ ...settings, payoutBankName: event.target.value })}
                    />
                  </label>

                  <label>
                    Account Holder
                    <input
                      type="text"
                      value={settings.payoutAccountHolder || ''}
                      onChange={(event) => setSettings({ ...settings, payoutAccountHolder: event.target.value })}
                    />
                  </label>

                  <label>
                    Account Number
                    <input
                      type="text"
                      inputMode="numeric"
                      value={settings.payoutAccountNumber || ''}
                      onChange={(event) => setSettings({ ...settings, payoutAccountNumber: event.target.value })}
                    />
                  </label>

                  <label>
                    Account Type
                    <input
                      type="text"
                      placeholder="Business Cheque"
                      value={settings.payoutAccountType || ''}
                      onChange={(event) => setSettings({ ...settings, payoutAccountType: event.target.value })}
                    />
                  </label>

                  <label>
                    Branch Code
                    <input
                      type="text"
                      inputMode="numeric"
                      value={settings.payoutBranchCode || ''}
                      onChange={(event) => setSettings({ ...settings, payoutBranchCode: event.target.value })}
                    />
                  </label>

                  <label className="fullWidthField">
                    Settlement Reference
                    <input
                      type="text"
                      placeholder="KAZI settlements"
                      value={settings.payoutReference || ''}
                      onChange={(event) => setSettings({ ...settings, payoutReference: event.target.value })}
                    />
                  </label>
                </div>
              </div>
            </div>
          ) : (
            <p className="emptyState">Sign in as an admin to load platform settings.</p>
          )}
        </article>

        <article className="surfacePanel reviewPanel">
          <div className="sectionHeader">
            <div>
              <p className="eyebrow compact">Marketplace Pulse</p>
              <h2>Bookings and payments overview</h2>
            </div>
            <button type="button" className="secondaryButton" onClick={() => void loadDashboard()} disabled={loading || !token.trim()}>
              Refresh Metrics
            </button>
          </div>

          {metrics ? (
            <div className="metricsStack">
              <div className="metricsGrid">
                <article className="miniMetricCard">
                  <span>Customers</span>
                  <strong>{metrics.customerCount}</strong>
                </article>
                <article className="miniMetricCard">
                  <span>Providers</span>
                  <strong>{metrics.providerCount}</strong>
                </article>
                <article className="miniMetricCard">
                  <span>Active bookings</span>
                  <strong>{metrics.activeBookings}</strong>
                </article>
                <article className="miniMetricCard">
                  <span>Scheduled</span>
                  <strong>{metrics.scheduledBookings}</strong>
                </article>
                <article className="miniMetricCard">
                  <span>Completed</span>
                  <strong>{metrics.completedBookings}</strong>
                </article>
                <article className="miniMetricCard">
                  <span>Average rating</span>
                  <strong>{metrics.averageRating.toFixed(1)}</strong>
                </article>
              </div>

              <div>
                <div className="sectionHeader compactHeader">
                  <div>
                    <p className="eyebrow compact">Payment Feed</p>
                    <h2>Recent transactions</h2>
                  </div>
                </div>

                {recentPayments.length === 0 ? (
                  <p className="emptyState">No payment transactions have been created yet.</p>
                ) : (
                  <div className="paymentFeed">
                    {recentPayments.map((payment) => (
                      <article className="paymentRow" key={payment.id}>
                        <div>
                          <strong>{payment.bookingRef || payment.bookingId}</strong>
                          <p>
                            {payment.paymentMethod.toUpperCase()} • {payment.status.toUpperCase()} • {new Date(payment.updatedAt).toLocaleString()}
                          </p>
                        </div>
                        <div className="paymentMeta">
                          <strong>{formatCurrency(payment.amountCents)}</strong>
                          <span>Commission {formatCurrency(payment.commissionCents)}</span>
                          <span>Payout {formatCurrency(payment.providerEarningsCents)}</span>
                          {payment.checkoutUrl ? (
                            <a href={payment.checkoutUrl} target="_blank" rel="noreferrer" className="documentLink">
                              Open checkout
                            </a>
                          ) : null}
                        </div>
                      </article>
                    ))}
                  </div>
                )}
              </div>
            </div>
          ) : (
            <p className="emptyState">Sign in as an admin to load booking and payment analytics.</p>
          )}
        </article>

        <article className="surfacePanel reviewPanel">
          <div className="sectionHeader">
            <div>
              <p className="eyebrow compact">Verification Queue</p>
              <h2>Provider document review</h2>
            </div>
            <button type="button" className="secondaryButton" onClick={() => void loadDashboard()} disabled={loading || !token.trim()}>
              Refresh Queue
            </button>
          </div>

          {pendingProviders.length === 0 ? (
            <p className="emptyState">No providers are currently waiting for verification review.</p>
          ) : (
            <div className="providerList">
              {pendingProviders.map((provider) => {
                const name = [provider.user?.firstName, provider.user?.lastName].filter(Boolean).join(' ') || 'Unnamed provider';

                return (
                  <article className="providerCard" key={provider.userId}>
                    <div className="providerHeader">
                      <div>
                        <h3>{name}</h3>
                        <p>{provider.user?.phone} {provider.user?.email ? `• ${provider.user.email}` : ''}</p>
                      </div>
                      <span className="statusPill pending">Pending</span>
                    </div>

                    <div className="providerMeta">
                      <span>{provider.serviceArea || 'Service area not provided'}</span>
                      <span>{provider.yearsExperience || 0} years experience</span>
                      <span>{provider.documents.length} uploaded files</span>
                    </div>

                    <div className="documentList">
                      {provider.documents.map((document) => (
                        <div className="documentRow" key={document.id}>
                          <div>
                            <strong>{document.documentType.replace(/_/g, ' ')}</strong>
                            <p>{document.fileName}</p>
                          </div>
                          {document.fileUrl ? (
                            <a href={document.fileUrl} target="_blank" rel="noreferrer" className="documentLink">
                              View file
                            </a>
                          ) : (
                            <span className="documentMissing">Missing file URL</span>
                          )}
                        </div>
                      ))}
                    </div>

                    <label>
                      Review note
                      <textarea
                        rows={3}
                        value={reviewNotes[provider.userId] || ''}
                        onChange={(event) => setReviewNotes((current) => ({
                          ...current,
                          [provider.userId]: event.target.value,
                        }))}
                        placeholder="Add a compliance note for this review"
                      />
                    </label>

                    <div className="actionRow">
                      <button type="button" className="secondaryButton" onClick={() => void reviewProvider(provider.userId, 'rejected')}>
                        Reject
                      </button>
                      <button type="button" className="primaryButton" onClick={() => void reviewProvider(provider.userId, 'approved')}>
                        Approve
                      </button>
                    </div>
                  </article>
                );
              })}
            </div>
          )}
        </article>
      </section>
    </main>
  );
}