import { FormEvent, useEffect, useMemo, useState } from 'react';

type PlatformSettings = {
  defaultCommissionRate: number;
  cashPaymentsEnabled: boolean;
  cardPaymentsEnabled: boolean;
  walletPaymentsEnabled: boolean;
  instantBookingsEnabled: boolean;
  scheduledBookingsEnabled: boolean;
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

const DEFAULT_API_BASE_URL = 'http://localhost:3001/api/v1';

export function App() {
  const [apiBaseUrl, setApiBaseUrl] = useState(() => localStorage.getItem('kazi.admin.apiBaseUrl') || DEFAULT_API_BASE_URL);
  const [token, setToken] = useState(() => localStorage.getItem('kazi.admin.token') || '');
  const [settings, setSettings] = useState<PlatformSettings | null>(null);
  const [pendingProviders, setPendingProviders] = useState<PendingProvider[]>([]);
  const [reviewNotes, setReviewNotes] = useState<Record<string, string>>({});
  const [loading, setLoading] = useState(false);
  const [savingSettings, setSavingSettings] = useState(false);
  const [statusMessage, setStatusMessage] = useState('');
  const [errorMessage, setErrorMessage] = useState('');

  const stats = useMemo(() => {
    const pendingCount = pendingProviders.length;
    const documentCount = pendingProviders.reduce((count, provider) => count + provider.documents.length, 0);
    return [
      { label: 'Pending Reviews', value: String(pendingCount).padStart(2, '0'), detail: 'Provider verification queue' },
      { label: 'Documents Submitted', value: String(documentCount).padStart(2, '0'), detail: 'Files ready for compliance review' },
      {
        label: 'Commission Rate',
        value: settings ? `${Math.round(settings.defaultCommissionRate * 100)}%` : '--',
        detail: 'Applied to newly created bookings',
      },
    ];
  }, [pendingProviders, settings]);

  useEffect(() => {
    localStorage.setItem('kazi.admin.apiBaseUrl', apiBaseUrl);
  }, [apiBaseUrl]);

  useEffect(() => {
    localStorage.setItem('kazi.admin.token', token);
  }, [token]);

  useEffect(() => {
    if (!token.trim()) return;
    void loadDashboard();
  }, []);

  async function request<T>(path: string, init?: RequestInit) {
    const response = await fetch(`${apiBaseUrl}${path}`, {
      ...init,
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
        ...(init?.headers || {}),
      },
    });

    if (!response.ok) {
      const text = await response.text();
      throw new Error(text || `Request failed with status ${response.status}`);
    }

    return response.json() as Promise<T>;
  }

  async function loadDashboard(event?: FormEvent) {
    event?.preventDefault();
    if (!token.trim()) {
      setErrorMessage('Paste an admin bearer token before connecting.');
      return;
    }

    setLoading(true);
    setErrorMessage('');
    setStatusMessage('');

    try {
      const [settingsResponse, pendingResponse] = await Promise.all([
        request<PlatformSettings>('/admin/settings'),
        request<PendingProvider[]>('/admin/providers/pending-verification'),
      ]);

      setSettings(settingsResponse);
      setPendingProviders(pendingResponse);
      setStatusMessage('Admin console connected.');
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Failed to load admin dashboard.');
    } finally {
      setLoading(false);
    }
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
        <div>
          <p className="eyebrow">KAZI Admin</p>
          <h1>Compliance, commission, and launch control for the South African MVP.</h1>
          <p className="lede">
            This console now talks to the real admin APIs for platform settings and provider
            verification review. Use it to control commission policy and clear onboarding queues.
          </p>
        </div>
        <div className="heroBadge">af-south-1 operations</div>
      </section>

      <section className="authPanel surfacePanel">
        <form className="authForm" onSubmit={loadDashboard}>
          <label>
            API Base URL
            <input value={apiBaseUrl} onChange={(event) => setApiBaseUrl(event.target.value)} placeholder={DEFAULT_API_BASE_URL} />
          </label>
          <label className="tokenField">
            Admin Bearer Token
            <textarea value={token} onChange={(event) => setToken(event.target.value)} rows={3} placeholder="Paste a JWT for an admin user" />
          </label>
          <button type="submit" className="primaryButton" disabled={loading}>
            {loading ? 'Connecting...' : 'Connect Admin Console'}
          </button>
        </form>
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
              <h2>Commission and booking controls</h2>
            </div>
            <button type="button" className="primaryButton" onClick={saveSettings} disabled={!settings || savingSettings}>
              {savingSettings ? 'Saving...' : 'Save Settings'}
            </button>
          </div>

          {settings ? (
            <div className="settingsForm">
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
          ) : (
            <p className="emptyState">Connect with an admin token to load platform settings.</p>
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