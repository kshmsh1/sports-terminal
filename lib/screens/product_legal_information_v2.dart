import 'package:flutter/material.dart';

const sportsTerminalTermsVersion = '2026-08-08-v1';
const sportsTerminalPrivacyVersion = '2026-08-08-v1';
const sportsTerminalLegalEffectiveDate = 'August 8, 2026';

const _legalPanel = Color(0xFF0F151C);
const _legalPanel2 = Color(0xFF141C25);
const _legalLine = Color(0xFF263342);
const _legalText = Color(0xFFE8EDF3);
const _legalMuted = Color(0xFF9AA6B5);
const _legalBlue = Color(0xFF63A9FF);
const _legalAmber = Color(0xFFE2B866);
const _legalGreen = Color(0xFF69C99A);

class ProductLegalInformationScreen extends StatelessWidget {
  const ProductLegalInformationScreen({super.key, required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final document = switch (kind) {
      'privacy' => _privacy,
      'terms' => _terms,
      'contact' => _contact,
      _ => _about,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalHero(document: document),
        const SizedBox(height: 14),
        if (kind == 'privacy' || kind == 'terms') ...[
          _LegalNotice(kind: kind),
          const SizedBox(height: 14),
        ],
        _TableOfContents(document: document),
        const SizedBox(height: 14),
        for (var index = 0; index < document.sections.length; index++) ...[
          _LegalSectionCard(index: index + 1, section: document.sections[index]),
          const SizedBox(height: 11),
        ],
      ],
    );
  }
}

class LegalDoc {
  const LegalDoc({required this.eyebrow, required this.title, required this.summary, required this.version, required this.sections});
  final String eyebrow;
  final String title;
  final String summary;
  final String version;
  final List<LegalSection> sections;
}

class LegalSection {
  const LegalSection(this.title, this.body, {this.points = const []});
  final String title;
  final String body;
  final List<String> points;
}

const _privacy = LegalDoc(
  eyebrow: 'LEGAL / PRIVACY',
  title: 'Sports Terminal Privacy Policy',
  version: sportsTerminalPrivacyVersion,
  summary: 'This Privacy Policy explains how Sports Terminal collects, uses, discloses, retains, protects and otherwise processes personal information across accounts, profiles, statistics and research tools, community, messaging, editorial products, workspaces, Python execution, organizations, subscriptions, support and related services.',
  sections: [
    LegalSection('Scope and relationship to other notices', 'This Policy applies to Sports Terminal websites, applications, APIs, account services, community features, communications, research workspaces and other products that link to it. Product-specific, just-in-time, employment, applicant, vendor or enterprise notices may supplement this Policy. If a supplemental notice conflicts with this Policy for a specific processing activity, the more specific notice controls to the extent stated there.'),
    LegalSection('Who is responsible for your information', 'The legal entity operating Sports Terminal will be identified here before public launch together with its principal business address and, where legally required, representative or data-protection contact. For consumer services, Sports Terminal generally determines why and how personal information is processed. For certain organization-controlled workspaces, Sports Terminal may process information on an organization’s instructions and the organization may separately determine the purposes of processing.'),
    LegalSection('Information you provide directly', 'We may collect information you submit when creating or maintaining an account, participating in community or messaging, configuring preferences, contacting support, purchasing services, applying to organizations or using research tools.', points: [
      'Account and identity information such as name, display name, username or handle, email address, password-derived credentials, organization affiliation, role and account status.',
      'Profile information such as avatar or profile image, biography, location if you choose to provide it, favorite teams and players, sports interests, public badges, profile visibility and other preferences.',
      'Community and communications content including posts, comments, votes, reactions, saved items, reports, moderation appeals, direct or group messages and attachments where supported.',
      'Research and workspace content including watchlists, notes, saved searches, models, formulas, code, notebook inputs, routed datasets, trade scenarios, transaction cases and organization collaboration content.',
      'Support, survey, partnership, press, trust-and-safety, privacy-request and other correspondence.',
      'Billing and transaction information. Payment card or bank credentials should be processed by a payment provider rather than stored directly by Sports Terminal where feasible.'
    ]),
    LegalSection('Information collected automatically', 'When you access or use the Services, we and service providers may automatically collect technical and usage information needed to operate, secure, measure and improve the platform.', points: [
      'Device, browser, operating system, app version, language, screen characteristics and similar device attributes.',
      'IP address, approximate region derived from IP, timestamps, requested URLs or screens, referrer information and network diagnostics.',
      'Authentication and security events including sign-in attempts, session identifiers, device/session history, failed logins, abuse signals and account-security events.',
      'Usage events such as features viewed, searches, filters, clicks, saved objects, navigation paths, performance timings, crashes and feature interactions.',
      'Cookie, local-storage, SDK or comparable identifiers where these technologies are used. Non-essential tracking will be managed through consent or opt-out mechanisms where legally required.'
    ]),
    LegalSection('Sports, research and derived data', 'Most statistics, schedules, standings, transactions, player/team identifiers, historical records and other sports information are not personal information about a Sports Terminal user. However, your queries, watchlists, saved research, predictions, private notes, organization work and interaction history may be associated with your account and therefore can be personal information. We may derive product analytics, preferences, rankings or recommendations from your interactions, subject to applicable law and the controls described in this Policy.'),
    LegalSection('Information from other sources', 'We may receive information from identity, payment, analytics, hosting, anti-abuse, customer-support, enterprise, social or other integrations you choose to connect; from organizations that provision or administer your access; from public or licensed data sources; and from other users when they interact with or report content involving you. We will process third-party information consistent with the source permissions, our agreements and applicable law.'),
    LegalSection('Purposes of processing', 'We process personal information for legitimate product, contractual, security, legal and business purposes, and where required based on consent.', points: [
      'Create, authenticate, maintain and secure accounts and sessions.',
      'Provide statistics, research, saved workspaces, Python execution, trade tools, community, messaging, editorial, organization and other requested functionality.',
      'Remember preferences and personalize teams, players, content, alerts and product experiences.',
      'Operate moderation, anti-spam, fraud prevention, rate limiting, abuse detection, account sanctions, appeals and platform integrity systems.',
      'Provide customer support, service notices, security notices and requested communications.',
      'Analyze reliability, feature adoption, performance and aggregate usage; debug, test and improve the Services.',
      'Administer subscriptions, billing, entitlements, trials and account plans.',
      'Enforce our Terms, protect users and the public, defend legal claims, comply with legal process and meet regulatory obligations.',
      'Develop and evaluate new features, including statistical and machine-learning features, subject to applicable law and disclosed controls.'
    ]),
    LegalSection('Legal bases where applicable', 'Where laws such as the GDPR or UK GDPR require a legal basis, processing may rely on performance of a contract when necessary to provide requested Services; legitimate interests such as security, fraud prevention, service improvement and business operations where those interests are not overridden by your rights; compliance with legal obligations; protection of vital interests in limited safety situations; or consent where consent is required. The applicable basis depends on the processing context.'),
    LegalSection('Personalization, recommendations and profiling', 'We may use account preferences, favorite teams or players, followed communities, reading and research activity, saved items and similar signals to rank or recommend content and features. We will provide controls or legally required rights relating to profiling, targeted advertising or certain automated decision-making when those laws apply. Sports Terminal does not intend to make solely automated decisions that produce legal or similarly significant effects on ordinary consumer users without providing required safeguards.'),
    LegalSection('Cookies, local storage and similar technologies', 'We may use strictly necessary technologies for authentication, security, preferences, load balancing and core functionality. Analytics, advertising or cross-context behavioral technologies, if introduced, will be separately identified and subject to consent, opt-out or Global Privacy Control handling where required. Browser local storage may retain preferences, cached workspace state and session-adjacent data. Clearing browser data may remove locally stored settings.'),
    LegalSection('How we disclose information', 'We do not sell user data in the ordinary meaning of exchanging personal information for money. We may disclose information to categories of recipients necessary to operate the Services, and some privacy laws define “sale” or “sharing” more broadly than an exchange for money.', points: [
      'Cloud hosting, database, content-delivery, security, monitoring and infrastructure providers.',
      'Authentication, email, customer-support, analytics, payment and other service providers acting under contract.',
      'Your organization, administrators or collaborators when you use an organization account or deliberately share organization-visible content.',
      'Other users or the public for information you choose to make public, such as public profile fields, posts, comments, votes or published articles.',
      'Professional advisers, auditors, insurers, financing sources and transaction counterparties subject to appropriate confidentiality protections.',
      'Courts, regulators, law enforcement or other parties where disclosure is required by law or reasonably necessary to protect rights, safety, security, property, users or the public.',
      'A successor or participant in a merger, acquisition, financing, reorganization, bankruptcy, sale of assets or similar corporate transaction, subject to applicable law.'
    ]),
    LegalSection('Public content and visibility', 'Public usernames, profile fields, community posts, comments, votes, articles and other public contributions may be visible to anyone, indexed by search services, copied or reshared by others and remain available outside our control after deletion from Sports Terminal. Private messages and private workspaces are not intended to be public, although authorized recipients, organization administrators where applicable, safety reviewers in limited circumstances and service providers may process them as necessary to provide and protect the Services.'),
    LegalSection('Organization accounts', 'If an employer, team, agency, media company, school or other organization provides your account, that organization may control membership, roles, shared workspaces, cases, organization-visible activity and retention. Administrators may be able to access or manage organization content consistent with product settings and the organization agreement. Do not use an organization workspace for personal content you do not want the organization to control.'),
    LegalSection('Community safety, moderation and legal requests', 'We may process posts, comments, messages, account history, reports, blocks, mutes and technical signals to detect or investigate spam, harassment, impersonation, threats, fraud, illegal content, intellectual-property complaints and other Terms violations. We may preserve relevant information when reasonably necessary for investigations, appeals, litigation holds or legal obligations even after ordinary deletion periods.'),
    LegalSection('Nonconsensual intimate imagery and urgent safety', 'Where legally required or operationally appropriate, Sports Terminal will maintain reporting and removal channels for nonconsensual intimate imagery, child sexual abuse material, credible threats and other high-risk content. Valid legal removal requests may require expedited removal, preservation or reporting. The public launch process must include jurisdiction-appropriate procedures, trained escalation and required reporting relationships.'),
    LegalSection('Copyright and intellectual-property complaints', 'Copyright notices and counter-notices may contain names, contact details, signatures, statements under penalty of perjury and descriptions of disputed content. We may disclose a notice or counter-notice to the affected user or rights holder as required to process the request and may retain records for compliance, repeat-infringer enforcement and dispute resolution.'),
    LegalSection('Data retention', 'We retain information only as long as reasonably necessary for the purposes described in this Policy, including account operation, security, dispute resolution, contractual commitments and legal obligations. Retention varies by category. Active account/profile data may remain while the account is active; public content may remain until deleted or moderated; security and audit records may be retained longer; backups may age out on a delayed schedule; and legal holds may override normal deletion. Before launch, Sports Terminal will publish or internally adopt more specific retention schedules for material data categories.'),
    LegalSection('Security', 'We use administrative, technical and organizational safeguards designed to protect information, such as access controls, password hashing, transport encryption in production, environment separation, least-privilege practices, logging, vulnerability management, backup controls and abuse monitoring. No system is perfectly secure. You are responsible for safeguarding credentials and promptly reporting suspected account compromise.'),
    LegalSection('Data minimization and sensitive information', 'Do not submit unnecessary highly sensitive information to community posts, profiles, messages, notes or notebooks. Unless a specific feature expressly requests it, Sports Terminal is not designed to collect government identification numbers, precise health records, biometric templates, account passwords for unrelated services, private cryptographic keys or other highly sensitive secrets. We may restrict or remove such information for safety and data-minimization reasons.'),
    LegalSection('Children and age-related protections', 'Sports Terminal is intended for a general audience and is not directed to children under 13 in the United States. We do not knowingly collect personal information from a child under 13 without legally required parental consent. Age thresholds and parental-consent rules vary by jurisdiction. If we learn that information was collected in violation of applicable children’s privacy law, we will take appropriate steps to delete or otherwise remediate it. Youth-facing features, if any, will receive a separate privacy and safety review before launch.'),
    LegalSection('United States state privacy rights', 'Depending on your state, applicable law and our processing activities, you may have rights to know or access categories or specific pieces of personal information; obtain a portable copy; correct inaccuracies; delete information; opt out of sale, sharing, targeted advertising or certain profiling; limit certain uses of sensitive information; appeal a denied request; and receive nondiscriminatory treatment for exercising privacy rights. We will honor legally recognized browser-based opt-out preference signals such as Global Privacy Control where required.'),
    LegalSection('California disclosures', 'If the California Consumer Privacy Act applies to Sports Terminal for a given period, California residents may receive the rights and disclosures required by that law. Categories potentially collected are described throughout this Policy and may include identifiers, customer records, commercial/subscription information, internet or electronic activity, approximate geolocation, professional/organization information, user-generated audio/visual content, and inferences or preferences. Sports Terminal will provide a Notice at Collection and required methods for exercising California rights before engaging in covered processing.'),
    LegalSection('EEA, United Kingdom and similar jurisdictions', 'Where European or UK data-protection law applies, individuals may have rights to information, access, rectification, erasure, restriction, portability, objection and safeguards concerning certain automated decisions. You may also have a right to complain to an applicable supervisory authority. International transfers will use a legally recognized transfer mechanism where required, such as adequacy decisions, contractual clauses or another valid safeguard.'),
    LegalSection('International users and transfers', 'Sports Terminal may operate infrastructure or use providers in countries other than where you live. Privacy and data-protection laws vary. Where required, we will implement transfer safeguards and provide information about relevant mechanisms. Organization customers may receive additional data-processing and transfer terms.'),
    LegalSection('Your choices and account controls', 'Depending on the feature, you can edit profile information; change public/private visibility; select favorite teams, players and interests; manage alerts and marketing communications; delete posts or other content where supported; block or mute users; manage sessions and passwords; and request privacy rights. Transactional, security or legally required notices may not be optional while you maintain an account.'),
    LegalSection('Marketing communications', 'If Sports Terminal sends promotional email or similar marketing, it will provide legally required sender identification and opt-out mechanisms. Opting out of marketing does not prevent transactional messages such as password, security, billing, moderation, legal or service notices. We will not condition product reviews or testimonials on a required positive or negative sentiment.'),
    LegalSection('Advertising and cross-context sharing', 'Sports Terminal does not currently need advertising to define the core privacy model. If advertising, retargeting or cross-context behavioral advertising is introduced, this Policy and consent/opt-out interfaces will be updated before that processing begins where required. Users will be given legally mandated controls, including applicable sale/share or targeted-advertising opt-outs.'),
    LegalSection('AI and machine-learning features', 'Sports Terminal may use machine-learning systems to support search, recommendations, moderation, summaries, analytics or research workflows. Inputs and outputs may contain personal information when you include it. We will disclose material model/provider data uses, retention and training arrangements where relevant. We will not represent model outputs as guaranteed facts and will maintain human or appeal processes where legally required for significant automated decisions.'),
    LegalSection('De-identified and aggregate information', 'We may create aggregated or de-identified information that is not reasonably linkable to an identifiable individual and use it for analytics, research, benchmarking, product development and business purposes. Where law treats de-identified information specially, we will maintain required safeguards and will not attempt to re-identify it except as permitted for testing those safeguards.'),
    LegalSection('Business transfers', 'If Sports Terminal or relevant assets are involved in a financing, merger, acquisition, restructuring, insolvency, sale or similar transaction, personal information may be reviewed or transferred as part of that transaction subject to confidentiality and applicable law. Any successor’s use of personal information remains subject to legal obligations and applicable notices.'),
    LegalSection('Do Not Track and opt-out preference signals', 'Browser “Do Not Track” signals do not have a single universally applicable legal meaning. Sports Terminal will describe how it responds if DNT functionality is implemented. Where applicable law requires recognition of an opt-out preference signal such as Global Privacy Control for sale, sharing or targeted advertising, the production platform will honor that signal.'),
    LegalSection('Exercising privacy rights', 'A dedicated privacy request portal and email address will be inserted before public launch. Requests may require identity or authority verification proportionate to the sensitivity of the request. Authorized agents may be supported where required. We may deny or limit a request when an exception applies and will explain appeal rights where required. We will not discriminate against you for exercising applicable privacy rights.'),
    LegalSection('Changes to this Policy', 'We may update this Policy to reflect product, legal, security or business changes. The page will display the effective date and version. If changes are material, we will provide additional notice or obtain renewed consent where required. Continued use alone will not substitute for affirmative consent when applicable law requires affirmative consent.'),
    LegalSection('Contact and regulatory inquiries', 'Privacy questions, requests, regulator correspondence and data-protection contacts will be routed through the Contact page. Production launch requires insertion of the operating legal entity, postal address, privacy email, any required data protection officer or representative, and any jurisdiction-specific regulator information.'),
  ],
);

const _terms = LegalDoc(
  eyebrow: 'LEGAL / TERMS',
  title: 'Sports Terminal Terms & Conditions',
  version: sportsTerminalTermsVersion,
  summary: 'These Terms govern access to and use of Sports Terminal. They establish account rules, licenses, acceptable use, intellectual-property protection, community standards, sports-data and analytical disclaimers, subscription terms, enforcement rights, dispute provisions and other conditions necessary to protect users and the platform.',
  sections: [
    LegalSection('Acceptance and binding agreement', 'By creating an account, purchasing or activating a plan, or otherwise using an authenticated portion of Sports Terminal, you agree to these Terms and acknowledge the Privacy Policy. Account creation requires separate affirmative acceptance of the current Terms and Privacy Policy versions. If you use Sports Terminal for an organization, you represent that you are authorized to bind yourself and, where applicable, to act for that organization within the permissions granted to you.'),
    LegalSection('Eligibility', 'You must be legally capable of entering into this agreement. Sports Terminal is not directed to children under 13 in the United States. Additional minimum ages or parental-consent requirements may apply by jurisdiction. If you use an organization account, you must satisfy any organization eligibility or authorization requirements.'),
    LegalSection('Changes to Terms', 'Sports Terminal may modify these Terms when product, legal, security or business requirements change. Updated Terms will display a new version and effective date. Material changes may require renewed affirmative acceptance before continued authenticated use. Changes do not retroactively alter accrued rights except where permitted by law.'),
    LegalSection('Accounts and credentials', 'You must provide accurate account information, keep credentials confidential, use reasonable security practices and promptly report unauthorized use. You may not sell, rent, lend, sublicense or transfer an account except through an authorized organization-management feature. You are responsible for activity performed through your account to the extent permitted by law. Sports Terminal may require password resets, session revocation, identity verification or other security measures.'),
    LegalSection('Organization accounts and administrators', 'Organizations may provision members, establish roles and access organization workspaces, cases, records and other shared content. Organization administrators are responsible for granting appropriate permissions and obtaining any notices or consents required for information they submit. Your organization may control or retain organization content even after your individual membership ends. Separate enterprise or organization terms may supplement these Terms.'),
    LegalSection('License to use the Services', 'Subject to these Terms and any plan limitations, Sports Terminal grants you a limited, personal or internal-business, revocable, nonexclusive, nontransferable and nonsublicensable right to access and use the Services through authorized interfaces. No ownership of Sports Terminal technology, data compilations, brands or other proprietary materials is transferred to you.'),
    LegalSection('Sports Terminal intellectual property', 'Sports Terminal and its licensors retain all right, title and interest in the Services and associated software, source and object code, user interfaces, visual design, workflows, features, models, taxonomies, schemas, metric definitions and presentation, database organization, compilations, documentation, trademarks, logos, domain names, trade dress, product names, inventions, know-how and other intellectual property, except for third-party materials expressly identified as belonging to their respective owners.'),
    LegalSection('Restrictions on copying and competitive use', 'Except where applicable law prohibits the restriction or Sports Terminal gives written permission, you may not copy, reproduce, republish, mirror, frame, white-label, resell or commercially redistribute material portions of the Services; use the Services to create or train a substantially substitutable or competing product or dataset; systematically extract database contents; remove proprietary notices; or use Sports Terminal branding in a way likely to imply sponsorship or affiliation.'),
    LegalSection('No scraping, crawling or automated extraction without permission', 'You may not use bots, spiders, scrapers, headless browsers, automated agents or other means to access or extract the Services at scale except through an expressly authorized API, documented export feature or written agreement. You may not circumvent robots controls, rate limits, authentication, paywalls, technical protection measures or access controls. Search engines may crawl public pages only to the extent authorized by our technical instructions and applicable law.'),
    LegalSection('No reverse engineering or circumvention', 'To the maximum extent permitted by law, you may not reverse engineer, decompile, disassemble, decode or attempt to derive nonpublic source code, models, system prompts, security mechanisms or proprietary algorithms; probe or circumvent technical controls; exploit vulnerabilities; or interfere with the integrity or availability of the Services. Nothing in this section limits rights that cannot lawfully be waived.'),
    LegalSection('Third-party sports data and materials', 'The Services may display data, names, statistics, schedules, scores, transactions, logos, images, articles, links or other materials obtained from or relating to leagues, teams, players, public sources, licensed providers or other third parties. Third-party materials remain subject to the rights, licenses, attribution requirements and restrictions applicable to those materials. Sports Terminal does not claim ownership of third-party trademarks or copyrighted materials merely by displaying or referencing them.'),
    LegalSection('User content ownership', 'As between you and Sports Terminal, you retain ownership of original content you create and submit, subject to rights you grant here and rights held by third parties in material you include. You represent that you have the rights and permissions necessary to submit your content and that doing so does not violate law, contract, privacy, publicity, intellectual-property or other rights.'),
    LegalSection('License for user content', 'You grant Sports Terminal a worldwide, nonexclusive, royalty-free license to host, store, reproduce, format, adapt for technical display, distribute and display user content as reasonably necessary to operate, secure, improve and provide the Services and according to the visibility you select. For public content, the license includes making that content available to other users and the public. This operational license ends when content is deleted except for copies retained in backups, legal holds, moderation records or by recipients, and except where continued retention is otherwise permitted by law.'),
    LegalSection('Feedback', 'If you voluntarily provide product ideas, suggestions or feedback, you grant Sports Terminal a perpetual, irrevocable, worldwide, royalty-free right to use, modify, commercialize and incorporate that feedback without restriction or compensation, provided this does not transfer ownership of your separate copyrighted works or confidential organization materials.'),
    LegalSection('Acceptable use', 'You may use Sports Terminal only for lawful purposes and in compliance with these Terms. Prohibited conduct includes unauthorized access; malware; denial-of-service activity; phishing; credential theft; spam; fraud; impersonation; evasion of sanctions or access controls; unlawful surveillance; doxxing; harassment; threats; exploitation; nonconsensual intimate imagery; child sexual abuse material; unlawful discrimination; intellectual-property infringement; illegal transactions; and other conduct that creates material risk to users or the platform.'),
    LegalSection('Community standards', 'Community participation requires good-faith discussion and respect for other users. Sports Terminal may establish board-specific rules, remove or reduce distribution of content, lock discussions, require labels, limit posting, quarantine accounts or communities, and take other moderation actions. Users may criticize Sports Terminal and other users in good faith; moderation will not be conditioned on positive sentiment.'),
    LegalSection('Votes, reputation and platform integrity', 'Votes, reactions, follows, badges, reputation, rankings and similar signals are product features, not property or guaranteed entitlements. You may not buy, sell, automate, coordinate or manipulate them deceptively. Sports Terminal may reverse fraudulent or abusive signals, remove fake accounts and adjust ranking systems to protect integrity.'),
    LegalSection('Moderation and enforcement discretion', 'Sports Terminal may investigate suspected violations and take proportionate action including warnings, content removal, reduced distribution, feature restrictions, temporary suspension, organization escalation or account termination. Serious or repeated violations may result in immediate action. Where appropriate, we may preserve evidence, notify affected parties, respond to lawful requests or refer matters to authorities. Appeals may be offered according to applicable law and platform policy.'),
    LegalSection('Messages and private communications', 'Private messaging may be subject to automated or human safety review in limited circumstances such as user reports, abuse detection, security incidents or legal obligations. You may not use messages for spam, threats, exploitation, unlawful solicitation or circumvention of community enforcement. Blocking may prevent new communications between affected accounts.'),
    LegalSection('Copyright policy and repeat infringement', 'Users must respect copyright and related rights. Sports Terminal will maintain a copyright notice-and-counter-notice process and, where applicable, a registered DMCA agent. We may remove or disable access to allegedly infringing material and terminate repeat infringers in appropriate circumstances. Knowingly materially misrepresenting infringement or counter-notice facts may create legal consequences.'),
    LegalSection('Trademarks, publicity rights and impersonation', 'You may not impersonate a person, team, league, company or organization or use names, marks, logos, likenesses or other indicia in a way that violates applicable rights or falsely implies affiliation. Fan discussion and lawful nominative or expressive use are not automatically prohibited, but account names, verification indicators and commercial activity may be restricted to reduce confusion.'),
    LegalSection('Articles, blogs and editorial content', 'Articles and blogs may include analysis, opinion, reporting, community contributions and automated assistance. The views of individual authors do not necessarily represent Sports Terminal. Editors may correct, update, label, archive or remove content. Sponsored or materially connected content must be disclosed as required by law and platform policy.'),
    LegalSection('Statistics, analytics and model outputs', 'Sports statistics, probabilities, projections, rankings, derived metrics, AI outputs, salary-cap calculations, trade validations and other analysis are informational tools. Sources may be incomplete, delayed, conflicting or revised. Models may contain assumptions and errors. You are responsible for independently verifying information before making material decisions.'),
    LegalSection('Trade Machine and salary-cap tools', 'Trade Machine results are research aids and not official NBA, team, player, agent or legal determinations. Collective-bargaining rules, contract terms, trade bonuses, guarantees, options, exceptions, draft-pick restrictions, aggregation rules and transaction timing can be complex and may change. A scenario marked “valid” means only that it passed the rules implemented by the current Sports Terminal engine and does not guarantee league approval.'),
    LegalSection('No investment, legal, tax, medical or professional advice', 'Unless a separately licensed professional service expressly states otherwise, Sports Terminal does not provide legal, investment, tax, accounting, medical, employment-agent or other regulated professional advice. Information about contracts, salaries, team finances or business transactions is informational and should not replace qualified professional advice.'),
    LegalSection('Fantasy sports, predictions and gambling-related information', 'Statistics, projections, fantasy tools and game analysis are intended for informational and entertainment purposes. Sports Terminal does not guarantee outcomes and does not by default operate a sportsbook or accept wagers. Users are responsible for complying with age, location and other laws governing fantasy contests, sports wagering or similar activity. Sports Terminal may restrict gambling-related functionality by jurisdiction.'),
    LegalSection('Python Lab and user code', 'Python Lab is a bounded analytical environment, not a general-purpose compute service. You may not attempt to escape the sandbox, access prohibited network/file/process capabilities, execute malicious code, mine cryptocurrency, attack infrastructure or process data you are not authorized to use. Runtime limits, allowed syntax and helper functions may change. Execution may be logged for reliability and security.'),
    LegalSection('APIs, exports and developer access', 'Any API key, data export or developer interface is subject to documentation, rate limits, field restrictions, attribution obligations and plan limits. You may not evade quotas by rotating accounts or credentials. We may suspend keys or change APIs to protect security, contractual data rights or service reliability. Separate developer terms may apply.'),
    LegalSection('Plans, subscriptions and paid features', 'If paid plans are offered, pricing, billing frequency, included features, taxes and renewal terms will be presented at purchase. Unless otherwise stated, subscriptions may renew automatically until canceled. Any legally required pre-renewal notices, cancellation mechanisms and trial disclosures will be provided. Plan features, quotas and pricing may change prospectively with required notice.'),
    LegalSection('Trials, promotions and credits', 'Trials, promotional pricing, referral credits or other offers may have eligibility, duration and usage limits. We may revoke credits obtained through fraud, duplicate accounts or abuse. Credits are not cash, have no value outside Sports Terminal and expire as disclosed, except where applicable law requires otherwise.'),
    LegalSection('Cancellation and refunds', 'Users may cancel a subscription using the account or billing method provided. Cancellation ordinarily stops future renewal while preserving access through the paid period unless otherwise disclosed. Refund availability will be stated in purchase terms and is subject to mandatory consumer rights. Fraudulent chargebacks or payment disputes may result in suspension while investigated.'),
    LegalSection('Taxes', 'Prices may exclude taxes unless stated otherwise. You are responsible for taxes, duties or similar governmental charges associated with your purchase except taxes based on Sports Terminal’s net income. Sports Terminal or its payment provider may calculate, collect and remit taxes where required.'),
    LegalSection('Third-party services and links', 'The Services may interoperate with or link to third-party websites, applications, identity providers, payment systems, data vendors, social networks or other services. Sports Terminal does not control third-party services and is not responsible for their availability, content, security, privacy or terms. Your use of them is governed by their own agreements.'),
    LegalSection('Beta, experimental and source-gated features', 'Features labeled beta, preview, experimental, modeled, estimated, source-gated or similar may be incomplete, change without notice, produce incorrect results or be discontinued. Do not rely on experimental features for decisions requiring authoritative information. Sports Terminal may impose separate confidentiality or feedback conditions for closed previews.'),
    LegalSection('Service changes and availability', 'We may add, modify, suspend or discontinue features, interfaces, data sources or plan offerings. We aim for reliable service but do not guarantee uninterrupted availability. Maintenance, provider outages, legal restrictions, security incidents, force majeure events or data-source changes may affect access. Where practicable, material paid-feature reductions will be handled consistent with applicable law and customer agreements.'),
    LegalSection('Data-source and rights-holder changes', 'Sports data and content rights may depend on licenses, public availability, technical interfaces and contractual restrictions. Sports Terminal may remove, replace, delay or restrict a dataset or feature if necessary to comply with rights, provider terms or law. You have no entitlement to the permanent availability of a particular third-party dataset unless a written enterprise agreement expressly guarantees it.'),
    LegalSection('Suspension and termination', 'You may stop using Sports Terminal and may request account closure subject to applicable retention. Sports Terminal may suspend or terminate access for material or repeated Terms violations, nonpayment, fraud, security risk, legal requirements, misuse of data or intellectual property, or conduct that materially harms the platform or others. Where law or circumstances allow, we may provide notice and an opportunity to cure or appeal.'),
    LegalSection('Effect of termination', 'Upon termination, your license to access the Services ends. Provisions that by their nature should survive—including intellectual-property ownership, feedback rights, accrued payment obligations, disclaimers, limitations of liability, indemnification, dispute terms and certain content licenses—continue to apply. Organization content may remain with the organization according to its agreement and retention settings.'),
    LegalSection('Disclaimer of warranties', 'TO THE MAXIMUM EXTENT PERMITTED BY LAW, THE SERVICES ARE PROVIDED “AS IS” AND “AS AVAILABLE.” SPORTS TERMINAL DISCLAIMS IMPLIED WARRANTIES INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, TITLE, NON-INFRINGEMENT AND WARRANTIES ARISING FROM COURSE OF DEALING OR USAGE. WE DO NOT WARRANT THAT DATA, MODELS, CONTENT OR RESULTS ARE COMPLETE, ACCURATE, CURRENT, UNINTERRUPTED, SECURE OR ERROR-FREE. SOME JURISDICTIONS DO NOT ALLOW CERTAIN DISCLAIMERS, SO THOSE LIMITATIONS MAY NOT APPLY TO YOU.'),
    LegalSection('Limitation of liability', 'TO THE MAXIMUM EXTENT PERMITTED BY LAW, SPORTS TERMINAL AND ITS AFFILIATES, OFFICERS, DIRECTORS, EMPLOYEES, CONTRACTORS, LICENSORS AND SERVICE PROVIDERS WILL NOT BE LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY OR PUNITIVE DAMAGES, OR LOSS OF PROFITS, REVENUE, DATA, GOODWILL OR BUSINESS OPPORTUNITY, ARISING FROM THE SERVICES. A PRODUCTION VERSION OF THESE TERMS MUST INSERT AN APPROPRIATE AGGREGATE LIABILITY CAP AND ANY REQUIRED CONSUMER-LAW CARVEOUTS AFTER COUNSEL REVIEW. LIABILITY THAT CANNOT LEGALLY BE LIMITED REMAINS UNAFFECTED.'),
    LegalSection('Indemnification', 'To the extent permitted by law and, for consumer users, only to the extent enforceable in the applicable jurisdiction, you agree to defend, indemnify and hold harmless Sports Terminal and its affiliates from third-party claims arising from your unlawful user content, material breach of these Terms, infringement or misappropriation of third-party rights, or misuse of the Services. Enterprise/customer agreements may contain different indemnification provisions.'),
    LegalSection('Release regarding other users', 'Sports Terminal provides platforms for users to interact but is not responsible for every user statement, transaction or dispute. To the extent permitted by law, you release Sports Terminal from claims arising solely from disputes between you and another user, except to the extent caused by Sports Terminal’s own actionable conduct. This does not waive rights that cannot legally be waived.'),
    LegalSection('Governing law and venue', 'The production Terms must identify the operating entity’s governing law and forum after corporate domicile and launch jurisdictions are finalized. Mandatory consumer protections in your jurisdiction may override a contractual governing-law or venue provision. This placeholder must be replaced before public launch.'),
    LegalSection('Arbitration and class-action provisions', 'Sports Terminal may adopt a properly drafted arbitration agreement and class-action waiver where lawful and appropriate, including opt-out procedures and jurisdiction-specific exceptions. No binding arbitration clause is activated by this draft because the operating entity, governing law, arbitration provider, venue, fees, mass-arbitration procedures and legally required disclosures have not been finalized. Counsel must complete this section before relying on arbitration.'),
    LegalSection('Export controls and sanctions', 'You may not use the Services in violation of applicable trade restrictions, export controls or sanctions. You represent that your use is lawful in your location and that you will not use the Services for prohibited end uses or on behalf of prohibited persons where applicable.'),
    LegalSection('Government use', 'Government users may be subject to additional procurement, records, security or statutory requirements. Unless a written agreement says otherwise, the Services are commercial computer software and commercial data/services provided under these Terms to the maximum extent permitted by applicable procurement law.'),
    LegalSection('Assignment', 'You may not assign these Terms or transfer contractual rights to another person without Sports Terminal’s consent except where applicable law provides otherwise. Sports Terminal may assign these Terms in connection with a merger, acquisition, reorganization, financing, sale of assets or transfer to an affiliate, subject to applicable law and any required notice.'),
    LegalSection('Force majeure', 'Sports Terminal is not responsible for delay or failure caused by events beyond reasonable control, such as natural disasters, war, civil unrest, labor disputes, government action, widespread network or cloud failures, provider outages or other force majeure events, except where liability cannot be excluded by law.'),
    LegalSection('Notices', 'Sports Terminal may provide legal or service notices electronically through the Services, account email or another reasonable method. You are responsible for maintaining a current email address. Formal notice addresses and procedures for the operating entity will be inserted before production launch.'),
    LegalSection('Entire agreement, waiver and severability', 'These Terms, the Privacy Policy and any incorporated or supplemental terms form the agreement governing the Services unless a signed agreement says otherwise. Failure to enforce a provision is not a waiver. If a provision is unenforceable, it will be modified or severed to the minimum extent necessary while the remainder continues in effect, subject to any special rule applicable to a future arbitration provision.'),
    LegalSection('No third-party beneficiaries', 'Except where expressly stated, these Terms do not create third-party beneficiary rights. Sports Terminal affiliates or indemnified parties may enforce provisions expressly intended for their benefit to the extent permitted by law.'),
    LegalSection('Interpretation', 'Headings are for convenience. “Including” means including without limitation. Electronic records and signatures may be used to the extent permitted by law. If translated, the controlling-language provision will be specified before launch. Rights and remedies are cumulative unless stated otherwise.'),
    LegalSection('Contact', 'Questions about these Terms, legal notices, copyright, partnerships or platform access should use the Contact page. Before public launch, Sports Terminal will insert the operating entity’s legal name, registered or business address, formal notice email and any required registered-agent or jurisdiction-specific information.'),
  ],
);

const _about = LegalDoc(
  eyebrow: 'COMPANY',
  title: 'About Sports Terminal',
  version: 'platform-vision-v1',
  summary: 'Sports Terminal is an NBA-first sports intelligence, workflow, editorial and community platform being built to bring professional-grade sports data and operating tools into one coherent product.',
  sections: [
    LegalSection('What we are building', 'Sports Terminal combines deep sports data, historical research, player and team intelligence, advanced analytics, transaction modeling, saved workspaces, code-based analysis, editorial content and community. The goal is not to create another box-score site; it is to create durable infrastructure through which fans, analysts, creators and organizations can understand and work with sports.'),
    LegalSection('NBA first', 'The platform is deliberately NBA-first while the data architecture, research workflows, community systems, identity model and operating infrastructure are hardened. Other sports can later reuse the same platform primitives without weakening the quality of the NBA product.'),
    LegalSection('Data philosophy', 'Sports Terminal preserves source provenance, distinguishes observed data from derived estimates and models, avoids presenting unavailable statistics as facts, separates regular season from playoffs, and keeps historical data queryable rather than flattening it into a small consumer snapshot.'),
    LegalSection('Research philosophy', 'A metric should be understandable, reproducible where possible and connected to its source or methodology. Advanced and proprietary-style models belong beside—not in place of—basic statistics. Analysts should be able to move from a player or team page into deeper data, notebooks, comparisons and transaction workflows without losing context.'),
    LegalSection('Community and publishing', 'Sports knowledge is social. Team rooms, long-form analysis, comments, public profiles, saved work and reputation systems are designed to make serious analysis and fandom coexist. Safety, moderation and user controls are treated as infrastructure rather than afterthoughts.'),
    LegalSection('Who it is for', 'The intended audience includes fans, fantasy players, data-driven hobbyists, writers and creators, students, analysts, media professionals, agents, team and league staff, investors and other sports organizations. Features and access levels can differ across personal and organization accounts.'),
    LegalSection('Independence and trademarks', 'Sports Terminal is an independent product unless a future page expressly states an official partnership. NBA, WNBA, NFL, NHL, MLB, NCAA, MLS, Premier League, UEFA and team/player names and marks belong to their respective rights holders. References are descriptive and do not imply endorsement.'),
    LegalSection('Company information', 'PLACEHOLDER BEFORE LAUNCH: legal entity name, jurisdiction of formation, principal office, leadership/team information, press boilerplate, careers link and official social accounts.'),
  ],
);

const _contact = LegalDoc(
  eyebrow: 'SUPPORT / CONTACT',
  title: 'Contact Sports Terminal',
  version: 'contact-v1',
  summary: 'Use the appropriate channel so product, data, privacy, legal, safety, press and partnership requests reach the right workflow. Addresses below are launch placeholders until the operating entity and production support stack are finalized.',
  sections: [
    LegalSection('General support', 'PLACEHOLDER: support@sportsterminal.example. Use for account access, product questions, subscriptions, billing, bugs and general support. Include the affected account email, browser/app version and a concise description; never email your password.'),
    LegalSection('Data corrections', 'PLACEHOLDER: data@sportsterminal.example. Report incorrect player/team identity, statistics, schedules, standings, award records, contract facts, source conflicts or missing historical data. Include the page, season, field, expected value and a reliable source when possible.'),
    LegalSection('Privacy requests', 'PLACEHOLDER: privacy@sportsterminal.example plus a production privacy request portal. Use for access, correction, deletion, portability, opt-out, consent or other privacy-right requests. Sports Terminal may verify identity or authorized-agent authority as required by law.'),
    LegalSection('Trust & safety', 'PLACEHOLDER: safety@sportsterminal.example. Use for harassment, credible threats, impersonation, nonconsensual intimate imagery, child-safety matters, spam, fraud, ban appeals and urgent platform-safety issues. Imminent emergencies should be directed to appropriate emergency services.'),
    LegalSection('Copyright / DMCA', 'PLACEHOLDER: copyright@sportsterminal.example. Before U.S. public launch, the operating entity should designate and register a DMCA agent if it intends to rely on applicable safe-harbor procedures. The final page will publish the agent’s name, postal address, phone number and email.'),
    LegalSection('Legal process', 'PLACEHOLDER: legal@sportsterminal.example. Use for formal legal correspondence, subpoenas, preservation requests and rights-holder matters. A formal notice address and instructions for law-enforcement requests will be inserted before production.'),
    LegalSection('Press and editorial', 'PLACEHOLDER: press@sportsterminal.example. Use for media inquiries, corrections concerning Sports Terminal reporting, interview requests and editorial partnerships.'),
    LegalSection('Teams, leagues, agencies and data partnerships', 'PLACEHOLDER: partnerships@sportsterminal.example. Use for league/team/agency relationships, enterprise deployments, licensing, official data, content syndication, integrations and commercial partnerships.'),
    LegalSection('Security reports', 'PLACEHOLDER: security@sportsterminal.example and a responsible-disclosure policy. Do not exploit or publicly disclose a suspected vulnerability before giving the security team reasonable time to investigate. A vulnerability-reward or safe-harbor policy may be added later.'),
    LegalSection('Mailing address', 'PLACEHOLDER: Sports Terminal legal entity and physical mailing address to be inserted before public launch.'),
  ],
);

class _LegalHero extends StatelessWidget {
  const _LegalHero({required this.document});
  final LegalDoc document;
  @override
  Widget build(BuildContext context) => _Panel(
        child: LayoutBuilder(builder: (context, constraints) {
          final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(document.eyebrow, style: const TextStyle(color: _legalBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .9)),
            const SizedBox(height: 6),
            Text(document.title, style: const TextStyle(color: _legalText, fontSize: 31, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text(document.summary, style: const TextStyle(color: _legalMuted, height: 1.5)),
            const SizedBox(height: 9),
            Text('Effective: $sportsTerminalLegalEffectiveDate · Version: ${document.version}', style: const TextStyle(color: _legalBlue, fontSize: 10, fontWeight: FontWeight.w800)),
          ]);
          if (constraints.maxWidth < 850) return copy;
          return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(child: copy), const SizedBox(width: 24), _DocumentBadge(version: document.version)]);
        }),
      );
}

class _LegalNotice extends StatelessWidget {
  const _LegalNotice({required this.kind});
  final String kind;
  @override
  Widget build(BuildContext context) => _Panel(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.gavel_rounded, color: _legalAmber),
          const SizedBox(width: 10),
          Expanded(child: Text(
            kind == 'terms'
                ? 'Launch-control note: account creation is wired to require affirmative acceptance of this Terms version and the current Privacy Policy. Entity-specific governing law, liability cap, formal notices and any arbitration clause remain intentionally marked for counsel completion rather than invented here.'
                : 'Launch-control note: account creation is wired to require affirmative acknowledgment of this Privacy Policy together with the current Terms. Production launch still requires insertion of the operating entity, privacy contact, final retention schedule, production subprocessors/technologies and jurisdiction-specific notices based on actual data practices.',
            style: const TextStyle(color: _legalMuted, height: 1.45),
          )),
        ]),
      );
}

class _TableOfContents extends StatelessWidget {
  const _TableOfContents({required this.document});
  final LegalDoc document;
  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('CONTENTS', style: TextStyle(color: _legalBlue, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: .8)),
          const SizedBox(height: 9),
          Wrap(spacing: 8, runSpacing: 7, children: [
            for (var i = 0; i < document.sections.length; i++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: _legalPanel2, border: Border.all(color: _legalLine), borderRadius: BorderRadius.circular(6)),
                child: Text('${i + 1}. ${document.sections[i].title}', style: const TextStyle(color: _legalMuted, fontSize: 9, fontWeight: FontWeight.w700)),
              ),
          ]),
        ]),
      );
}

class _LegalSectionCard extends StatelessWidget {
  const _LegalSectionCard({required this.index, required this.section});
  final int index;
  final LegalSection section;
  @override
  Widget build(BuildContext context) => _Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 30, height: 30, alignment: Alignment.center, decoration: BoxDecoration(color: const Color(0x2263A9FF), border: Border.all(color: _legalBlue), borderRadius: BorderRadius.circular(7)), child: Text('$index', style: const TextStyle(color: _legalBlue, fontSize: 10, fontWeight: FontWeight.w900))),
            const SizedBox(width: 10),
            Expanded(child: Text(section.title, style: const TextStyle(color: _legalText, fontSize: 18, fontWeight: FontWeight.w900))),
          ]),
          const SizedBox(height: 10),
          SelectableText(section.body, style: const TextStyle(color: _legalMuted, height: 1.6, fontSize: 13)),
          if (section.points.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final point in section.points)
              Padding(
                padding: const EdgeInsets.only(bottom: 7, left: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 7), child: SizedBox(width: 5, height: 5, child: DecoratedBox(decoration: BoxDecoration(color: _legalBlue, shape: BoxShape.circle)))),
                  const SizedBox(width: 9),
                  Expanded(child: SelectableText(point, style: const TextStyle(color: _legalMuted, height: 1.5, fontSize: 12.5))),
                ]),
              ),
          ],
        ]),
      );
}

class _DocumentBadge extends StatelessWidget {
  const _DocumentBadge({required this.version});
  final String version;
  @override
  Widget build(BuildContext context) => Container(
        width: 160,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: _legalPanel2, border: Border.all(color: _legalLine), borderRadius: BorderRadius.circular(8)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.verified_user_outlined, color: _legalGreen),
          const SizedBox(height: 8),
          const Text('VERSIONED DOCUMENT', style: TextStyle(color: _legalMuted, fontSize: 8, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(version, style: const TextStyle(color: _legalText, fontSize: 10, fontWeight: FontWeight.w800)),
        ]),
      );
}

class _Panel extends StatelessWidget {
  const _Panel({required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: _legalPanel, border: Border.all(color: _legalLine), borderRadius: BorderRadius.circular(10)),
        child: child,
      );
}
