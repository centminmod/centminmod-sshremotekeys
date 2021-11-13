# Forked version

This is a forked version of original at https://github.com/FernandoMiguel/sshremotekeys

# SSH with Remote Keys storage

Securely maintain ssh keys to access servers is a tricky business. Keys have to be rotated regularly, individuals join/leave projects/companies, ssh key passwords are forgotten, etc.
#

Typically, admins add ssh keys to `~/.ssh/authorized_keys` or `%h/.ssh/authorized_keys`, others LDAP.

Updating these is a nightmare, even with packaging tools like ansile or puppet.

Some have crons to update these, but that can create a delay, and we all know what happens when you add delays.
#

Instead, I've opted to move away from managing keys in the instances, and move them to a centrally controlled location, where it is easy to update objects/permissions and have the instances check back on login attempt.

## Installation

```
git clone https://github.com/centminmod/centminmod-sshremotekeys
cd centminmod-sshremotekeys
# 1. modify sshauth-install.sh uri variable
# 2. modify userkeys.sh uri variable
# run sshauth-install.sh
./sshauth-install.sh
```

###
You will need to make 2 modifications

1. modify [sshauth-install.sh](sshauth-install.sh) and change the `uri` variable to your location of your `userkeys.sh` file i.e. `uri="https://raw.githubusercontent.com/centminmod/centminmod-sshremotekeys/master/userkeys.sh"` to use your server personalised version.
2. modify [userkeys.sh](userkeys.sh) and uncomment and modify the `uri` variable to the remote location which contains your SSH public keys i.e. a AWS S3 bucket or Githhub user keys

```
# uri="https://s3.amazonaws.com/BUCKET_NAME/devs.keys"
# uri="https://github.com/YOUR_GITHUB_USERNAME.keys"
```

Then [sshauth-install.sh](sshauth-install.sh) needs to be run in the instance. The script will modify `/etc/ssh/sshd_config`, pull your custom [userkeys.sh](userkeys.sh), and restart sshd.

It can be executed at anytime, or ideally during the creation of the instance. When deploying AWS instances, you can pass this with [UserData](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/user-data.html)

## Usage

SSH `AuthorizedKeysCommand` was introduced in [2013's OpenSSH 6.1](https://www.openssh.com/txt/release-6.2), although you will only find is commonly around in OpenSSH 6.9 distro packages.

From the manual:
> sshd(8): Added a sshd_config(5) option `AuthorizedKeysCommand` to support fetching authorized_keys from a command in addition to (or instead of) from the filesystem. The command is run under an account specified by an `AuthorizedKeysCommandUser` sshd_config(5) option.

This allows us to execute an arbitary command when a login attemp it made via ssh. 
In the case of this setup, it executes `userkeys.sh`

Depending on whether you are curling github API for keys [https://github.com/USER.keys] (for individual devs or extremelly small teams) or a s3 bucket object (one object per set of permissions), you will need to create your custom [userkeys.sh](userkeys.sh).

When there's an attempt login via ssh, sshd will execute `userkeys.sh`, which will then curl a file for ssh public keys, and match that against the one provided during login.

You can use `Match User` or `Match Group` to parse public keys against logins, but while increasing security, it also increases overhead.

## Gotchas


### Ed25519

ssh public key historicly have been created with RSA algorithm. But like everytghing in tech, that's old by today's standards.

The new shiny algorithm is [Ed25519](https://ed25519.cr.yp.to/).
It uses a Diffie-Hellman elliptic-curve, allowing it to be much smaller than tradicional RSA keys.
Where a good RSA key starts in 2048 bits, an Ed25519 is just 256.

Combine that with the easeness of reading, storing, curl them, you got a winner.

To generate one, run `$ ssh-keygen -t ed25519` with as many [rounds](https://crypto.stackexchange.com/questions/40311/how-many-kdf-rounds-for-an-ssh-key) as you see fit, and don't forget to password-protect it.

Copy the contents of its public key to [GitHub key settings](https://github.com/settings/keys) or your project permission object, and you are ready to go.


### Fail2Ban and general security

Please setup your instance with Fail2Ban, to prevent anyone from hammering your ssh port.

Also disable root `PermitRootLogin no` and disable passwords `PasswordAuthentication no`.

[sshauth-install.sh] already adds `AuthenticationMethods publickey` to `/etc/ssh/sshd_config`


### API rate limit

When curling against Internet webservices, developers need to account with services rate limits, in place to prevent abuse.

[GitHub API rate limit](https://developer.github.com/v3/#rate-limiting) is of `60 requests per hour` for unauthenticated requests, and `5000` when used with OAuth.

An AWS s3 bucket as a limit of `800 GET requests per second`.

#### Cache

If you have many devs login into a server or even bot scanning (hence [Fail2Ban](https://github.com/FernandoMiguel/sshremotekeys#fail2ban-and-general-security)), your host can easily reach the limit and prevent you from legitimately accessing your server.

To minimise this, the response of the external request (either Github or AWS) is saved to the file `$HOME/.ssh/authorized_keys_cache` and cached for 15 minutes via `userkeys.sh` variable `cacheValidity="900"`.

## Future Improvements

Right now, we are querying GitHub user profiles for sshkeys.

An advanced process can probably be developed using [GitHub GraphQL API](https://developer.github.com/early-access/graphql/) to queries Teams instead of users, allowing further control over Projects access

## License

[MIT](LICENSE)
