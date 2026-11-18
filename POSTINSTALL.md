Anchor is ready at https://$CLOUDRON-APP-FQDN.

<sso>
Cloudron OpenID Connect is enabled and password login is disabled. Sign in with Cloudron; the first user to sign in becomes the Anchor administrator.

Use the app's Access Control view in the Cloudron dashboard to select the users and groups that may sign in.
</sso>

<nosso>
Cloudron OpenID Connect is disabled. Register the first local account in Anchor; that account becomes the administrator.

An administrator can later configure another OpenID Connect provider in Anchor's own administration panel. Enabling Cloudron OpenID Connect itself requires reinstalling the app with SSO selected.
</nosso>

For the mobile client, use `https://$CLOUDRON-APP-FQDN` as the server URL.
