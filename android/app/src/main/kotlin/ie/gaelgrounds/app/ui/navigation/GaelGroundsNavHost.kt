package ie.gaelgrounds.app.ui.navigation

import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.Flag
import androidx.compose.material.icons.filled.Home
import androidx.compose.material.icons.filled.Person
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.SportsSoccer
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.navigation.NavDestination.Companion.hierarchy
import androidx.navigation.NavGraph.Companion.findStartDestination
import androidx.navigation.NavHostController
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.currentBackStackEntryAsState
import androidx.navigation.compose.rememberNavController
import androidx.navigation.navArgument
import ie.gaelgrounds.app.ui.counties.CountiesScreen
import ie.gaelgrounds.app.ui.counties.CountyDetailScreen
import ie.gaelgrounds.app.ui.counties.TeamDetailScreen
import ie.gaelgrounds.app.ui.dashboard.DashboardScreen
import ie.gaelgrounds.app.ui.friends.FriendsScreen
import ie.gaelgrounds.app.ui.grounds.GroundDetailScreen
import ie.gaelgrounds.app.ui.grounds.GroundsMapScreen
import ie.gaelgrounds.app.ui.grounds.GroundsScreen
import ie.gaelgrounds.app.ui.leaderboard.LeaderboardScreen
import ie.gaelgrounds.app.ui.matches.MatchDetailScreen
import ie.gaelgrounds.app.ui.matches.MatchesScreen
import ie.gaelgrounds.app.ui.profile.ProfileScreen

/**
 * Bottom-nav shell mirroring the 6-tab layout in
 * ios/GaelGrounds/Views/Root/MainTabView.swift (Home, Matches, Grounds,
 * Counties, Leaderboard, Profile). Friends is reached from Profile, same
 * as iOS, rather than being a 7th tab.
 */
private data class TopLevelDestination(
    val route: String,
    val label: String,
    val icon: androidx.compose.ui.graphics.vector.ImageVector,
)

private val topLevelDestinations = listOf(
    TopLevelDestination(Routes.DASHBOARD, "Home", Icons.Filled.Home),
    TopLevelDestination(Routes.MATCHES, "Matches", Icons.Filled.SportsSoccer),
    TopLevelDestination(Routes.GROUNDS, "Grounds", Icons.Filled.Place),
    TopLevelDestination(Routes.COUNTIES, "Counties", Icons.Filled.Flag),
    TopLevelDestination(Routes.LEADERBOARD, "Leaderboard", Icons.Filled.EmojiEvents),
    TopLevelDestination(Routes.PROFILE, "Profile", Icons.Filled.Person),
)

object Routes {
    const val DASHBOARD = "dashboard"
    const val MATCHES = "matches"
    const val GROUNDS = "grounds"
    const val COUNTIES = "counties"
    const val LEADERBOARD = "leaderboard"
    const val PROFILE = "profile"
    const val FRIENDS = "friends"
    const val GROUNDS_MAP = "grounds_map"
    const val MATCH_DETAIL = "match/{matchId}"
    const val GROUND_DETAIL = "ground/{groundId}"
    const val COUNTY_DETAIL = "county/{countyId}"
    const val TEAM_DETAIL = "team/{teamId}"

    fun matchDetail(id: String) = "match/$id"
    fun groundDetail(id: String) = "ground/$id"
    fun countyDetail(id: String) = "county/$id"
    fun teamDetail(id: String) = "team/$id"
}

@Composable
fun GaelGroundsNavHost(userEmail: String?, userId: String?, onSignOut: () -> Unit) {
    val navController: NavHostController = rememberNavController()

    Scaffold(
        bottomBar = {
            val backStackEntry by navController.currentBackStackEntryAsState()
            val currentRoute = backStackEntry?.destination
            NavigationBar {
                topLevelDestinations.forEach { destination ->
                    val selected = currentRoute?.hierarchy?.any { it.route == destination.route } == true
                    NavigationBarItem(
                        selected = selected,
                        onClick = {
                            navController.navigate(destination.route) {
                                popUpTo(navController.graph.findStartDestination().id) { saveState = true }
                                launchSingleTop = true
                                restoreState = true
                            }
                        },
                        icon = { Icon(destination.icon, contentDescription = destination.label) },
                        label = { Text(destination.label) },
                    )
                }
            }
        },
    ) { innerPadding ->
        NavHost(
            navController = navController,
            startDestination = Routes.DASHBOARD,
            modifier = Modifier.padding(innerPadding),
        ) {
            composable(Routes.DASHBOARD) {
                DashboardScreen(
                    userId = userId,
                    onOpenMatch = { navController.navigate(Routes.matchDetail(it)) },
                )
            }
            composable(Routes.MATCHES) {
                MatchesScreen(
                    userId = userId,
                    onOpenMatch = { navController.navigate(Routes.matchDetail(it)) },
                )
            }
            composable(
                Routes.MATCH_DETAIL,
                arguments = listOf(navArgument("matchId") {}),
            ) { backStackEntry ->
                val matchId = backStackEntry.arguments?.getString("matchId").orEmpty()
                MatchDetailScreen(matchId = matchId, userId = userId, onBack = { navController.popBackStack() })
            }
            composable(Routes.GROUNDS) {
                GroundsScreen(
                    userId = userId,
                    onOpenGround = { navController.navigate(Routes.groundDetail(it)) },
                    onOpenMap = { navController.navigate(Routes.GROUNDS_MAP) },
                )
            }
            composable(Routes.GROUNDS_MAP) {
                GroundsMapScreen(userId = userId, onBack = { navController.popBackStack() })
            }
            composable(
                Routes.GROUND_DETAIL,
                arguments = listOf(navArgument("groundId") {}),
            ) { backStackEntry ->
                val groundId = backStackEntry.arguments?.getString("groundId").orEmpty()
                GroundDetailScreen(groundId = groundId, userId = userId, onBack = { navController.popBackStack() })
            }
            composable(Routes.COUNTIES) {
                CountiesScreen(onOpenCounty = { navController.navigate(Routes.countyDetail(it)) })
            }
            composable(
                Routes.COUNTY_DETAIL,
                arguments = listOf(navArgument("countyId") {}),
            ) { backStackEntry ->
                val countyId = backStackEntry.arguments?.getString("countyId").orEmpty()
                CountyDetailScreen(
                    countyId = countyId,
                    onOpenTeam = { navController.navigate(Routes.teamDetail(it)) },
                    onOpenGround = { navController.navigate(Routes.groundDetail(it)) },
                    onBack = { navController.popBackStack() },
                )
            }
            composable(
                Routes.TEAM_DETAIL,
                arguments = listOf(navArgument("teamId") {}),
            ) { backStackEntry ->
                val teamId = backStackEntry.arguments?.getString("teamId").orEmpty()
                TeamDetailScreen(teamId = teamId, onBack = { navController.popBackStack() })
            }
            composable(Routes.LEADERBOARD) {
                LeaderboardScreen(userId = userId)
            }
            composable(Routes.PROFILE) {
                ProfileScreen(
                    userEmail = userEmail,
                    userId = userId,
                    onSignOut = onSignOut,
                    onOpenFriends = { navController.navigate(Routes.FRIENDS) },
                    onOpenMatch = { navController.navigate(Routes.matchDetail(it)) },
                    onOpenGround = { navController.navigate(Routes.groundDetail(it)) },
                )
            }
            composable(Routes.FRIENDS) {
                FriendsScreen(userId = userId, onBack = { navController.popBackStack() })
            }
        }
    }
}
