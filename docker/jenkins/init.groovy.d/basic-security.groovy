#!groovy

import jenkins.model.*
import hudson.security.*

def instance = Jenkins.get()

println "--> configuring local security"

def hudsonRealm = new HudsonPrivateSecurityRealm(false)
if (hudsonRealm.getUser("admin") == null) {
    println "--> creating admin user"
    hudsonRealm.createAccount("admin", "admin123!")
} else {
    println "--> admin user already exists"
}

instance.setSecurityRealm(hudsonRealm)

def strategy = new FullControlOnceLoggedInAuthorizationStrategy()
strategy.setAllowAnonymousRead(false)
instance.setAuthorizationStrategy(strategy)

instance.save()

println "--> Jenkins security configured"