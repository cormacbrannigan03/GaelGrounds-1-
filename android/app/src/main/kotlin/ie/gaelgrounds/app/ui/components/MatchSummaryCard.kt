package ie.gaelgrounds.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import ie.gaelgrounds.app.data.model.MatchSummary
import ie.gaelgrounds.app.ui.theme.BrandGold
import ie.gaelgrounds.app.ui.theme.BrandLive

/** Shared match row used by Dashboard and Matches -- mirrors MatchCardView.swift's info density. */
@Composable
fun MatchSummaryCard(match: MatchSummary, onClick: () -> Unit) {
    Card(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick),
        colors = CardDefaults.cardColors(),
    ) {
        Column(modifier = Modifier.padding(14.dp)) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text(
                    text = "${match.sportCode.icon} ${match.competition ?: match.sportCode.label}",
                    style = MaterialTheme.typography.labelMedium,
                )
                if (match.isLive) {
                    Text(
                        text = "LIVE",
                        color = BrandLive,
                        style = MaterialTheme.typography.labelSmall,
                        modifier = Modifier
                            .background(BrandLive.copy(alpha = 0.12f), RoundedCornerShape(6.dp))
                            .padding(horizontal = 6.dp, vertical = 2.dp),
                    )
                }
            }
            val scoreline = if (match.hasScore) {
                "${match.homeName} ${match.homeScore} - ${match.awayScore} ${match.awayName}"
            } else {
                "${match.homeName} v ${match.awayName}"
            }
            Text(
                text = scoreline,
                style = MaterialTheme.typography.titleMedium,
                modifier = Modifier.padding(top = 4.dp),
            )
            val winner = match.winnerName
            if (winner != null) {
                Text(
                    text = "$winner won",
                    color = BrandGold,
                    style = MaterialTheme.typography.labelSmall,
                )
            }
            Row(modifier = Modifier.padding(top = 6.dp), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                match.groundName?.let {
                    Text(it, style = MaterialTheme.typography.bodySmall)
                }
                if (match.attendeeCount > 0) {
                    Text("${match.attendeeCount} checked in", style = MaterialTheme.typography.bodySmall)
                }
            }
        }
    }
}
